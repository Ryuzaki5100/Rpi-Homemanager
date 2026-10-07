package com.example.bank;

public class Account {

    private final String id;
    private long balance;

    public Account(String id, long balance) {
        this.id = id;
        this.balance = balance;
    }

    public String id() {
        return id;
    }

    public synchronized long balance() {
        return balance;
    }

    public synchronized void debit(long amount) {
        if (balance < amount) {
            throw new IllegalStateException("insufficient funds in account " + id);
        }
        balance -= amount;
    }

    public synchronized void credit(long amount) {
        balance += amount;
    }
}
