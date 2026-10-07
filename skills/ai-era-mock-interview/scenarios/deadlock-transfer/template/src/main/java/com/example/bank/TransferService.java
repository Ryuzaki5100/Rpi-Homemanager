package com.example.bank;

/**
 * Transfers funds between two accounts. Each transfer locks both accounts
 * for the duration of the operation.
 */
public class TransferService {

    public void transfer(Account from, Account to, long amount) {
        synchronized (from) {
            simulateWork();
            synchronized (to) {
                from.debit(amount);
                to.credit(amount);
            }
        }
    }

    private static void simulateWork() {
        try {
            Thread.sleep(50);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
