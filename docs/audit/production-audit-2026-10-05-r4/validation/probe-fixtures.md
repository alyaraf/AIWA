# Audit-only reproduction fixtures

These fixtures ran in an isolated copy at commit 290a05f and intentionally assert the current defects. They are documentation, not application tests or fixes. Only synthetic identities, disposable directories and fake Docker commands are used. TMPDIR must be explicitly disposable; do not point these fixtures at live production volumes.


## Backend SOS mapper

```java
package com.aiwa.service.impl;
import com.aiwa.entity.*;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.SafetyEventType;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SafetyDestinationAuditProbeTest {
  @Test void sosAddressStillTracksEditedSavedAddressInsteadOfFrozenVisit() {
    User customer=User.builder().id(1L).fullName("Customer").build();
    User owner=User.builder().id(2L).fullName("Provider").build();
    ProviderProfile provider=ProviderProfile.builder().id(3L).user(owner).businessName("Provider").address("Provider base").build();
    SavedAddress address=SavedAddress.builder().id(4L).user(customer).addressLine("Agreed home A").latitude(30.0).longitude(31.0).build();
    Booking booking=Booking.builder().id(5L).customer(customer).provider(provider).savedAddress(address).homeService(true).status(BookingStatus.ACCEPTED).build();
    booking.snapshotDestination(address);
    address.setAddressLine("Edited unrelated home B");
    SafetyEvent sos=SafetyEvent.builder().id(6L).booking(booking).actor(customer).type(SafetyEventType.SOS).build();
    assertEquals("Agreed home A",BookingPrivacy.destinationOf(booking).getAddressLine());
    assertEquals("Edited unrelated home B",SafetyService.toAdminDto(sos).getAddress());
  }
}

```


## Dashboard session probes

```jsx
import { it, expect, vi } from 'vitest';
import { render, screen, fireEvent, act, waitFor } from '@testing-library/react';
import App from '../App.jsx';
import * as mod from '../api.js';

it('audit reproduction: private blob body survives a session change after headers', async () => {
  mod.setTokens({accessToken:'A'});
  let finish;
  const blob = vi.fn(() => new Promise(resolve => {finish=resolve;}));
  vi.spyOn(globalThis,'fetch').mockResolvedValue({status:200,ok:true,blob});
  const created=vi.fn(()=>'blob:private-A');
  vi.stubGlobal('URL', Object.assign(URL,{createObjectURL:created,revokeObjectURL:vi.fn()}));
  const pending=mod.api.verificationDocUrl('uploads/private/A.png');
  await vi.waitFor(()=>expect(finish).toBeTypeOf('function'));
  mod.clearTokens(); mod.setTokens({accessToken:'B'});
  finish(new Blob(['private document for A']));
  expect(await pending).toBe('blob:private-A');
  expect(created).toHaveBeenCalledTimes(1);
  console.log('REPRODUCED: private A blob exposed after B session starts');
});

it('audit reproduction: cross-tab new account retains a loaded restricted SOS row', async () => {
  mod.setTokens({accessToken:'A'});
  let who={id:1,fullName:'Support A',role:'ADMIN',permissions:['SUPER_ADMIN']};
  vi.spyOn(mod.api,'me').mockImplementation(async()=>who);
  vi.spyOn(mod.api,'dashboard').mockResolvedValue({stats:[],activity:[]});
  vi.spyOn(mod.api,'safetyQueue').mockResolvedValue([mod.normalizeSafety({id:99,bookingId:5,actorName:'Private A actor',notes:'PRIVATE_A_SOS',createdAt:new Date().toISOString()})]);
  vi.spyOn(globalThis,'fetch').mockResolvedValue({status:200,ok:true,text:async()=>JSON.stringify({data:{content:[],totalPages:1}})});
  render(<App/>);
  fireEvent.click(await screen.findByRole('button',{name:/Safety \(SOS\)/}));
  await screen.findByText(/PRIVATE_A_SOS/);
  who={id:2,fullName:'Finance B',role:'ADMIN',permissions:['FINANCE']};
  await act(async()=>{window.localStorage.setItem('aiwa_admin_session','new-B');window.dispatchEvent(new StorageEvent('storage',{key:'aiwa_admin_session',newValue:'new-B'}));});
  await screen.findByText(/Admin · Finance B/);
  expect(screen.getByText(/PRIVATE_A_SOS/)).toBeInTheDocument();
  expect(screen.queryByRole('button',{name:/Safety \(SOS\)/})).not.toBeInTheDocument();
  console.log('REPRODUCED: Finance B identity with restricted Support A SOS data still mounted');
},20000);

```


## Dashboard SOS ordering

```jsx
import {it,expect,vi} from 'vitest';
import {render,screen,act} from '@testing-library/react';
import {Safety,__setPermissionsForTest} from '../App.jsx';
import {api,normalizeSafety} from '../api.js';
it('audit reproduction: old initial SOS read overwrites a newer successful poll',async()=>{
  vi.useFakeTimers();
  try {
    window.localStorage.setItem('aiwa_admin_session','hint');
    __setPermissionsForTest(['SUPPORT']);
    let finishOld;
    const old=new Promise(resolve=>{finishOld=resolve;});
    const fresh=normalizeSafety({id:9,bookingId:5,actorName:'Customer',notes:'NEW_SOS',createdAt:new Date().toISOString()});
    const queue=vi.spyOn(api,'safetyQueue').mockReturnValueOnce(old).mockResolvedValue([fresh]);
    render(<Safety/>);
    await act(async()=>{await vi.advanceTimersByTimeAsync(15000);});
    expect(queue).toHaveBeenCalledTimes(2);
    await act(async()=>{finishOld([]);await vi.advanceTimersByTimeAsync(0);});
    expect(screen.getByText('No open SOS alerts')).toBeInTheDocument();
    expect(screen.getByText(/Live · updated/)).toBeInTheDocument();
    expect(screen.queryByText(/NEW_SOS/)).not.toBeInTheDocument();
  } finally {vi.useRealTimers();}
});

```


## Mobile auth races

```dart
import 'dart:async';
import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class Remote implements AuthRemoteDataSource {
  final a=Completer<Map<String,String>>();
  @override Future<Map<String,String>> login({required String identifier,required String password}) async {
    if(identifier=='A') return a.future;
    return {'accessToken':'B','refreshToken':'B-refresh','role':'CUSTOMER','userId':'2'};
  }
  @override Future<UserModel> getCurrentUser() async => UserModel.fromJson({'id':2,'fullName':'Bob','role':'CUSTOMER','email':'bob@example.test'});
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class SlowStorage extends SecureStorage {
  final remember=Completer<bool>();
  SlowStorage():super(const FlutterSecureStorage());
  @override Future<bool> getRemember()=>remember.future;
}
Future<void> settle()=>Future<void>.delayed(const Duration(milliseconds:50));
void main(){
  setUp(()=>FlutterSecureStorage.setMockInitialValues({}));
  test('audit reproduction: obsolete login failure removes current B auth state',() async{
    final remote=Remote(); final storage=SecureStorage(const FlutterSecureStorage());
    final bloc=AuthBloc(authRepository:AuthRepositoryImpl(remote,storage),secureStorage:storage);
    bloc.add(AuthLoginEvent(identifier:'A',password:'x',remember:true));await settle();
    bloc.add(AuthLoginEvent(identifier:'B',password:'x',remember:true));await settle();
    expect(bloc.state,isA<AuthAuthenticated>());
    remote.a.completeError(const SessionChangedException());await settle();
    expect(bloc.state,isA<AuthError>());
    expect(await storage.getAccessToken(),'B');
    await bloc.close();
  },tags:'audit-probe');
  test('audit reproduction: obsolete cold-start remember check deletes current B tokens',() async{
    final remote=Remote();final storage=SlowStorage();
    final bloc=AuthBloc(authRepository:AuthRepositoryImpl(remote,storage),secureStorage:storage);
    bloc.add(AuthCheckSessionEvent());await settle();
    bloc.add(AuthLoginEvent(identifier:'B',password:'x',remember:true));await settle();
    expect(bloc.state,isA<AuthAuthenticated>());expect(await storage.getAccessToken(),'B');
    storage.remember.complete(false);await settle();
    expect(bloc.state,isA<AuthUnauthenticated>());
    expect(await storage.getAccessToken(),isNull);
    await bloc.close();
  },tags:'audit-probe');
}

```


## OS rollback failures

```bash
#!/usr/bin/env bash
set -eu
export PATH="/usr/bin:/bin:$PATH"
work=$(mktemp -d "$TMPDIR/r4-rollback.XXXXXX")
# Disposable data only. Keep the directory for inspection; no live volumes or Docker are used.
mkdir -p "$work/live/public" "$work/source/public" "$work/bin"
printf 'OLD' > "$work/live/public/old.txt"
printf 'NEW' > "$work/source/public/new.txt"
tar -czf "$work/input.tgz" -C "$work/source" .
swap="$PWD/snapshot/deploy/backup/uploads_swap.sh"
UPLOADS_DIR="$work/live" sh "$swap" stage PROBE < "$work/input.tgz"
cat > "$work/bin/mv" <<'WRAPPER'
#!/bin/sh
case "$1" in
  */.restore-staging-*/public|*/.restore-previous-*/public) echo 'simulated OS rename failure' >&2; exit 1;;
esac
exec /usr/bin/mv "$@"
WRAPPER
chmod +x "$work/bin/mv"
set +e
PATH="$work/bin:$PATH" UPLOADS_DIR="$work/live" sh "$swap" swap PROBE
swap_rc=$?
PATH="$work/bin:$PATH" UPLOADS_DIR="$work/live" sh "$swap" rollback PROBE
rollback_rc=$?
set -e
printf 'swap exit=%s; rollback exit=%s; live old file=' "$swap_rc" "$rollback_rc"
if [ -f "$work/live/public/old.txt" ];then echo present;else echo MISSING;fi
printf 'previous old file='; [ -f "$work/live/.restore-previous-PROBE/public/old.txt" ] && echo present
printf 'journal=';if [ -f "$work/live/.restore-journal-PROBE" ];then echo retained;else echo DELETED;fi
printf 'fixture=%s\n' "$work"
if [ "$swap_rc" -eq 1 ] && [ "$rollback_rc" -eq 0 ] && [ ! -f "$work/live/public/old.txt" ];then echo 'REPRODUCED: failed rollback reports success with old uploads absent';else exit 2;fi

```


## Outer restore harness extension

```bash
#!/usr/bin/env bash
# Failure-injection test for the ORDER of restore.sh (audit I-02), with a fake docker (no containers needed):
#   bash deploy/restore_flow_test.sh
# The fake runs the real backup/uploads_swap.sh and backup/reconcile_uploads.sh against a temporary "volume", and
# records every call. It proves what restore.sh does when the extraction, the database restore or the swap fails:
# the live files and database are never left replaced-and-gone, and the backend is restarted (or deliberately kept
# stopped with instructions when nothing can be put back).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
pass=0; failed=0
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else failed=$((failed+1)); echo "FAIL $1"; fi; }
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# --- the fake docker --------------------------------------------------------------------------------------------
mkdir -p "$work/bin"
cat > "$work/bin/docker" <<'FAKE'
#!/bin/sh
# docker compose -f <file> <verb> ...
[ "$1" = compose ] || exit 1
shift; shift; shift   # compose -f file
verb="$1"; shift
echo "$verb $*" >> "$FAKE_LOG"
case "$verb" in
  stop|start) exit 0 ;;
  exec)
    # exec -T postgres <cmd...>
    shift; shift
    if [ "$1" = pg_restore ]; then cat > /dev/null; exit 0; fi   # --list
    script="$*"
    case "$script" in
      *"pg_dump -Fc"*) [ -n "${FAKE_NO_SAFETY:-}" ] && exit 1; echo "SAFETY-DUMP-OF-LIVE"; exit 0 ;;
      *"pg_restore --clean"*)
        cat > "$FAKE_STATE/restore-input"
        n=$(($(cat "$FAKE_STATE/restores" 2> /dev/null || echo 0) + 1)); echo "$n" > "$FAKE_STATE/restores"
        echo "db-restore #$n input=$(head -c 20 "$FAKE_STATE/restore-input" | tr -d '\n')" >> "$FAKE_LOG"
        [ -n "${FAKE_DB_RESTORE_FAILS:-}" ] && [ "$n" = "$FAKE_DB_RESTORE_FAILS" ] && exit 1
        [ -n "${FAKE_DB_RESTORE_FAILS_FROM:-}" ] && [ "$n" -ge "$FAKE_DB_RESTORE_FAILS_FROM" ] && exit 1
        exit 0 ;;
      *"pg_restore --no-owner"*) cat > /dev/null; exit 0 ;;   # scratch restore
      *psql*) cat > /dev/null; printf 'public|/files/public/avatars/n1.jpg\npublic|/files/public/avatars/gone.jpg\n'; exit 0 ;;
      *) cat > /dev/null; exit 0 ;;                           # createdb / dropdb
    esac ;;
  run)
    # run --rm -T --entrypoint sh backup /script args...
    while [ "$1" != backup ]; do shift; done; shift
    script="$1"; shift
    if [ "$1" = stage ] && [ -n "${FAKE_STAGE_FAILS:-}" ]; then cat > /dev/null; exit 1; fi
    case "$script" in
      /uploads_swap.sh) UPLOADS_DIR="$FAKE_VOLUME" UPLOADS_SWAP_FAIL_AFTER="${FAKE_SWAP_FAIL_AFTER:-}" sh "$FAKE_DEPLOY/backup/uploads_swap.sh" "$@" ;;
      /reconcile_uploads.sh) UPLOADS_DIR="$FAKE_VOLUME" sh "$FAKE_DEPLOY/backup/reconcile_uploads.sh" ;;
    esac ;;
esac
FAKE
chmod +x "$work/bin/docker"

# --- a disposable deploy directory and volume ------------------------------------------------------------------
new_case() {
  c="$work/$1"; shift
  mkdir -p "$c/deploy/backup" "$c/state" "$c/volume/public/avatars" "$c/volume/private/docs"
  cp "$here/restore.sh" "$c/deploy/"
  cp "$here/backup/uploads_swap.sh" "$here/backup/reconcile_uploads.sh" "$here/backup/uploads_references.sql" "$c/deploy/backup/"
  : > "$c/deploy/docker-compose.prod.yml"
  echo "old avatar" > "$c/volume/public/avatars/a1.jpg"
  echo "old id" > "$c/volume/private/docs/id1.png"
  mkdir -p "$c/src/public/avatars"; echo "new avatar" > "$c/src/public/avatars/n1.jpg"
  tar -czf "$c/uploads.tgz" -C "$c/src" .
  echo "DUMPDATA" > "$c/db.dump"
  : > "$c/log"
}
volume_sum() { ( cd "$1" && find . -path './.restore-*' -prune -o -type f -print | sort | xargs cksum ); }
# restore <case> [VAR=value ...]
restore() {
  c="$work/$1"; shift
  ( cd "$c/deploy" && env PATH="$work/bin:$PATH" FAKE_LOG="$c/log" FAKE_STATE="$c/state" FAKE_VOLUME="$c/volume" \
      FAKE_DEPLOY="$c/deploy" ASSUME_YES=1 "$@" bash ./restore.sh "$c/db.dump" "$c/uploads.tgz" ) > "$c/out" 2>&1
  rc=$?
}
called() { grep -q "$2" "$work/$1/log"; }
line_of() { grep -n "$2" "$work/$1/log" | head -1 | cut -d: -f1; }

# --- A: everything works -----------------------------------------------------------------------------------------
new_case A; restore A
check "A: a good restore succeeds" '[ $rc -eq 0 ]'
check "A: the live volume holds the restored files" '[ -f "$work/A/volume/public/avatars/n1.jpg" ] && [ ! -e "$work/A/volume/public/avatars/a1.jpg" ]'
check "A: the previous files are retained until purged" '[ -f "$work/A/volume/".restore-previous-*/public/avatars/a1.jpg ]'
check "A: a safety copy of the live database was taken before the restore" 'ls "$work/A/deploy/backups"/pre-restore-*.dump > /dev/null 2>&1'
check "A: staging happened BEFORE the backend was stopped" '[ "$(line_of A "stage ")" -lt "$(line_of A "^stop ")" ]'
check "A: the backend is started again at the end" 'called A "^start backend"'
check "A: the reconciliation report names the missing file" 'grep -q "MISSING public /files/public/avatars/gone.jpg" "$work/A/out" && grep -q "1 missing" "$work/A/out"'

# --- B: the extraction fails (disk full, damaged) ------------------------------------------------------------------
new_case B; before=$(volume_sum "$work/B/volume"); restore B FAKE_STAGE_FAILS=1
check "B: a failed extraction fails the restore" '[ $rc -ne 0 ]'
check "B: the live files are untouched" '[ "$(volume_sum "$work/B/volume")" = "$before" ]'
check "B: the backend was never stopped and the database never restored" '! called B "^stop " && ! called B "db-restore"'

# --- C: the database restore fails ------------------------------------------------------------------------------------
new_case C; before=$(volume_sum "$work/C/volume"); restore C FAKE_DB_RESTORE_FAILS=1
check "C: a failed database restore fails the run" '[ $rc -ne 0 ]'
check "C: the live files are untouched and the backend runs again" '[ "$(volume_sum "$work/C/volume")" = "$before" ] && called C "^start backend"'
check "C: the staged copy was discarded" '[ -z "$(ls -A "$work/C/volume" | grep "^.restore-staging")" ]'

# --- D: the swap fails after the database was restored: both are rolled back ----------------------------------------
new_case D; before=$(volume_sum "$work/D/volume"); restore D FAKE_SWAP_FAIL_AFTER=1
check "D: a failed swap fails the run" '[ $rc -ne 0 ]'
check "D: the live files are exactly as before" '[ "$(volume_sum "$work/D/volume")" = "$before" ]'
check "D: the database was put back from the safety copy (second restore, fed the safety dump)" 'called D "db-restore #2 input=SAFETY-DUMP-OF-LIVE"'
check "D: the backend is running again" 'called D "^start backend"'
check "D: the output says both are back" 'grep -q "back as they were" "$work/D/out"'

# --- E: the swap fails AND the database cannot be put back ----------------------------------------------------------
new_case E; restore E FAKE_SWAP_FAIL_AFTER=1 FAKE_DB_RESTORE_FAILS_FROM=2
check "E: the run fails" '[ $rc -ne 0 ]'
check "E: the backend stays stopped, deliberately" '! called E "^start backend"'
check "E: the message names the safety dump and says the old uploads are intact" 'grep -q "STOPPED" "$work/E/out" && grep -q "pre-restore-" "$work/E/out" && grep -q "intact" "$work/E/out"'
check "E: the live files are the old ones" '[ -f "$work/E/volume/public/avatars/a1.jpg" ]'

# --- F: no safety copy can be taken ------------------------------------------------------------------------------------------
new_case F; before=$(volume_sum "$work/F/volume"); restore F FAKE_NO_SAFETY=1
check "F: without a safety copy nothing is restored" '[ $rc -ne 0 ] && ! called F "db-restore" && [ "$(volume_sum "$work/F/volume")" = "$before" ] && called F "^start backend"'

echo "$pass passed, $failed failed"
[ "$failed" -eq 0 ]

# Audit-only extension: actual OS rename errors also affect the rollback path.
cat > "$work/bin/mv" <<'MV'
#!/bin/sh
case "$1" in
  */.restore-staging-*/public|*/.restore-previous-*/public) echo 'simulated OS rename failure' >&2; exit 1;;
esac
exec /usr/bin/mv "$@"
MV
chmod +x "$work/bin/mv"
new_case G; restore G
check "G: restore reports failure" '[ $rc -ne 0 ]'
check "G: despite failed file rollback the outer script restarts the backend" 'called G "^start backend"'
check "G: old public uploads are absent from the live path" '[ ! -f "$work/G/volume/public/avatars/a1.jpg" ]'
check "G: old public uploads are still stranded in previous" 'ls "$work/G/volume/".restore-previous-*/public/avatars/a1.jpg > /dev/null 2>&1'
check "G: output falsely claims both database and uploads are back" 'grep -q "database and uploads are both back" "$work/G/out"'
check "G: the retained safety dump is readable plaintext without the encryption key" 'grep -q "SAFETY-DUMP-OF-LIVE" "$work/G/deploy/backups/"pre-restore-*.dump'
cat "$work/G/out"
echo "REPRODUCTION CHECKS: $pass passed, $failed failed"
[ "$failed" -eq 0 ]

```

