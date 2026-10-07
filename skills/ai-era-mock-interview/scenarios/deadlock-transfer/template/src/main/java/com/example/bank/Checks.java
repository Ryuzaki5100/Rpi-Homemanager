package com.example.bank;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/** Dependency-free acceptance checks; also runnable via {@code java com.example.bank.Checks}. */
public final class Checks {

    private Checks() {
    }

    public static void runAll() {
        concurrentOppositeTransfersDoNotDeadlock();
        System.out.println("All transfer checks passed.");
    }

    /**
     * Two threads transfer in opposite directions at the same time. If locks are
     * acquired in inconsistent order, the pair deadlocks and neither future completes.
     */
    private static void concurrentOppositeTransfersDoNotDeadlock() {
        TransferService service = new TransferService();
        Account a = new Account("A", 1000);
        Account b = new Account("B", 1000);

        ExecutorService pool = Executors.newFixedThreadPool(2, r -> {
            Thread t = new Thread(r);
            t.setDaemon(true);
            return t;
        });
        CountDownLatch start = new CountDownLatch(1);
        try {
            Future<?> f1 = pool.submit(() -> {
                await(start);
                service.transfer(a, b, 10);
                return null;
            });
            Future<?> f2 = pool.submit(() -> {
                await(start);
                service.transfer(b, a, 10);
                return null;
            });
            start.countDown();
            f1.get(2, TimeUnit.SECONDS);
            f2.get(2, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            throw new AssertionError("deadlock: concurrent opposite transfers never completed");
        } catch (Exception e) {
            throw new AssertionError("transfer failed unexpectedly: " + e, e);
        } finally {
            pool.shutdownNow();
        }
    }

    private static void await(CountDownLatch latch) {
        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    public static void main(String[] args) {
        runAll();
    }
}
