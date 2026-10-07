# Solution — deadlock-transfer

**Root cause:** `TransferService.transfer` acquires locks in **argument order**
(`synchronized(from)` then `synchronized(to)`). When thread T1 transfers A→B and thread T2
transfers B→A concurrently, each acquires its first lock and waits forever for the second —
a classic lock-ordering deadlock.

**Fix:** acquire locks in a **consistent global order** (by account id) regardless of the
transfer direction.

```java
public void transfer(Account from, Account to, long amount) {
    Account first = from.id().compareTo(to.id()) < 0 ? from : to;
    Account second = (first == from) ? to : from;
    synchronized (first) {
        synchronized (second) {
            from.debit(amount);
            to.credit(amount);
        }
    }
}
```

**Why it works:** both threads now contend for the same "first" lock, so one proceeds
completely before the other; no cycle of lock ownership can form.

**Acceptable alternatives:** a single global transfer lock (simpler, less concurrent);
`ReentrantLock.tryLock(timeout)` with backoff and release-on-failure; a lock manager that
hands out locks in a canonical order. Simply removing the nested lock (allowing a torn
read) is **not** acceptable.

**Distractors:** the `simulateWork` sleep (it widens the race but is not the cause), and
per-account `synchronized` methods (individually correct, but do not prevent the cycle).
