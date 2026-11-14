#!/usr/bin/env python3
"""Dispatch ONCE and enforce a runner-queue deadline from the calling host.

Uses gh authentication internally; never prints credentials or raw API errors.
This is an external watchdog, not a workflow timeout or an automatic rerunner.
"""
import argparse
import json
from pathlib import Path
import re
import signal
import subprocess
import time
import uuid

JOB_NAME = 'Build unsigned iPhone IPA'


def wait_for_runner(fetch_jobs, cancel, *, start, timeout=300,
                    clock=time.monotonic, sleep=time.sleep):
    deadline = start + timeout
    while clock() < deadline:
        try:
            jobs = fetch_jobs(max(0.01, deadline - clock()))
        except (RuntimeError, subprocess.TimeoutExpired):
            jobs = []
        for job in jobs:
            if job.get('name') != JOB_NAME:
                continue
            if job.get('labels') != ['macos-26']:
                accepted = cancel()
                return {'state': 'runner_label_mismatch', 'cancel_requested': accepted is not False}
            has_started_step = any(s.get('started_at') and s.get('status') in {'in_progress', 'completed'}
                                   for s in job.get('steps', []))
            if (clock() < deadline and job.get('runner_id', 0) > 0
                    and job.get('status') in {'in_progress', 'completed'} and has_started_step):
                return {'state': 'runner_started', 'job_id': job['id'],
                        'runner_id': job['runner_id'], 'job_started_at': job.get('started_at'),
                        'queue_elapsed_seconds': round(clock() - start, 3)}
            if job.get('status') == 'completed' and not has_started_step:
                return {'state': 'macOS runner unavailable', 'cancel_requested': False,
                        'reason': 'Job completed without runner execution'}
        remaining = deadline - clock()
        if remaining > 0:
            sleep(min(2, remaining))
    # Initiate cancellation at the absolute deadline, even after API failures.
    elapsed = round(clock() - start, 3)
    accepted = cancel()
    return {'state': 'macOS runner unavailable', 'cancel_requested': accepted is not False,
            'queue_elapsed_seconds': elapsed}


def gh(args, timeout=8):
    result = subprocess.run(['gh', *args], capture_output=True, text=True, timeout=max(0.01, timeout))
    if result.returncode:
        raise RuntimeError('GitHub request failed; response details suppressed')
    return result.stdout


def api(endpoint, *, method='GET', timeout=8):
    output = gh(['api', '--method', method, endpoint], timeout=timeout)
    return json.loads(output) if output.strip() else {}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True)
    parser.add_argument('--workflow', default='unsigned-ipa.yml')
    parser.add_argument('--ref', default='main')
    parser.add_argument('--sha', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--queue-timeout', type=int, default=300, choices=range(1, 301))
    parser.add_argument('--build-timeout', type=int, default=1800)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repo):
        parser.error('Invalid repository identifier')
    if not re.fullmatch(r'[0-9a-f]{40}', args.sha):
        parser.error('Expected an exact lowercase 40-character commit SHA')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+\.ya?ml', args.workflow):
        parser.error('Expected a workflow filename')
    root = Path(__file__).resolve().parents[1]
    output = args.output.expanduser().resolve()
    if output.is_relative_to(root) or output.exists():
        parser.error('Output must be a NEW file outside the repository')
    if not 1 <= args.build_timeout <= 3600:
        parser.error('Build timeout must be 1...3600 seconds')
    prefix = f'repos/{args.repo}'
    tag = uuid.uuid4().hex
    report = {'repository': args.repo, 'workflow': args.workflow, 'ref': args.ref,
              'head_sha': args.sha, 'dispatch_tag': tag, 'queue_timeout_seconds': args.queue_timeout,
              'state': 'preflight', 'dispatch_count': 0, 'runner_label': 'macos-26'}
    run_id = None

    def save():
        output.parent.mkdir(parents=True, exist_ok=True)
        temp = output.with_suffix(output.suffix + '.tmp')
        temp.write_text(json.dumps(report, indent=2) + '\n')
        temp.replace(output)

    def emit(state):
        report['state'] = state
        save()
        print(json.dumps({'state': state, 'run_id': run_id, 'run_url': report.get('run_url')}), flush=True)

    def cancel():
        if run_id is None:
            return False
        report['cancel_requested_at'] = time.time()
        save()
        try:
            api(f'{prefix}/actions/runs/{run_id}/cancel', method='POST')
            return True
        except (RuntimeError, subprocess.TimeoutExpired):
            report['cancel_request_needs_verification'] = True
            save()
            return False

    def interrupted(*_):
        raise KeyboardInterrupt()

    signal.signal(signal.SIGTERM, interrupted)
    try:
        # Resolve the ref before dispatch; never run unverified or stale code.
        ref_sha = api(f'{prefix}/commits/{args.ref}')['sha']
        if ref_sha != args.sha:
            raise RuntimeError('Remote ref no longer matches the expected SHA')
        start = time.monotonic()
        report['dispatch_started_at'] = time.time()
        report['dispatch_count'] = 1
        emit('dispatching')
        # Exactly one dispatch. Unique run-name input disambiguates concurrent runs.
        try:
            gh(['workflow', 'run', args.workflow, '--repo', args.repo, '--ref', args.ref,
                '-f', f'build_tag={tag}'], timeout=min(8, args.queue_timeout))
        except (RuntimeError, subprocess.TimeoutExpired):
            # The server may have accepted a dispatch whose response was lost.
            # Resolve the unique tag; NEVER submit a second dispatch.
            report['dispatch_response_uncertain'] = True
            save()
        while run_id is None and time.monotonic() - start < args.queue_timeout:
            remaining = args.queue_timeout - (time.monotonic() - start)
            try:
                runs = api(f'{prefix}/actions/workflows/{args.workflow}/runs?event=workflow_dispatch&per_page=100',
                           timeout=min(3, remaining)).get('workflow_runs', [])
                matches = [r for r in runs if tag in r.get('display_title', '') and r.get('head_sha') == args.sha]
                if len(matches) == 1:
                    run_id = matches[0]['id']
                    report.update(run_id=run_id, run_url=matches[0]['html_url'])
                    emit('queued')
                    break
            except (RuntimeError, subprocess.TimeoutExpired):
                pass
            time.sleep(min(2, max(0, args.queue_timeout - (time.monotonic() - start))))
        if run_id is None:
            # No guessing another run's ID or cancelling unrelated workflows.
            raise RuntimeError('Dispatch identity unresolved; manual cancellation verification required')
        result = wait_for_runner(
            lambda remaining: api(f'{prefix}/actions/runs/{run_id}/jobs?per_page=100',
                                  timeout=min(3, remaining)).get('jobs', []),
            cancel, start=start, timeout=args.queue_timeout)
        report.update(result)
        emit(result['state'])
        if result['state'] != 'runner_started':
            # Read back the exact target; a cancel request alone is not cancellation.
            confirm_deadline = time.monotonic() + 60
            while time.monotonic() < confirm_deadline:
                run = api(f'{prefix}/actions/runs/{run_id}')
                report.update(final_status=run['status'], conclusion=run.get('conclusion'))
                save()
                if run['status'] == 'completed':
                    break
                time.sleep(2)
            return 2
        build_deadline = time.monotonic() + args.build_timeout
        while time.monotonic() < build_deadline:
            run = api(f'{prefix}/actions/runs/{run_id}')
            if run['head_sha'] != args.sha:
                raise RuntimeError('Run SHA mismatch')
            report.update(final_status=run['status'], conclusion=run.get('conclusion'))
            save()
            if run['status'] == 'completed':
                artifacts = api(f'{prefix}/actions/runs/{run_id}/artifacts?per_page=100')
                report['artifacts'] = [{k: a.get(k) for k in ['id', 'name', 'size_in_bytes', 'expired', 'digest']}
                                       for a in artifacts.get('artifacts', [])]
                emit('build_finished')
                return 0 if run.get('conclusion') == 'success' else 1
            time.sleep(5)
        cancel()
        emit('build_monitor_timeout')
        return 3
    except (RuntimeError, subprocess.TimeoutExpired, KeyboardInterrupt, OSError, ValueError) as error:
        if run_id is not None:
            cancel()
        report['error_type'] = type(error).__name__
        emit('monitor_error')
        return 3
    finally:
        save()


if __name__ == '__main__':
    raise SystemExit(main())
