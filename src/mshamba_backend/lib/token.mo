import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Types "types";
import Utils "utils";

module {
  public type Token = Types.Token;
  public type TokenHolder = Types.TokenHolder;
  public type Transaction = Types.Transaction;
  public type Result<T> = Utils.Result<T>;

  // In-memory store for token holders and transaction history
  public type TokenLedger = HashMap.HashMap<Text, TokenHolder>;
  public type TransactionHistory = HashMap.HashMap<Text, Transaction>;

  // Creates a new in-memory HashMap store for the token ledger
  public func newTokenLedger() : TokenLedger {
    HashMap.HashMap<Text, TokenHolder>(100, Text.equal, Text.hash)
  };

  // Creates a new in-memory HashMap store for transaction history
  public func newTransactionHistory() : TransactionHistory {
    HashMap.HashMap<Text, Transaction>(100, Text.equal, Text.hash)
  };

  // Mint new tokens for a farm
  public func mintTokens(
    farmId: Text,
    amount: Nat,
    owner: Principal,
    ledger: TokenLedger
  ) : Result<TokenHolder> {
    let key = farmId # Principal.toText(owner);
    let holder = switch (ledger.get(key)) {
      case (?h) {
        {
          ...h,
          amount = h.amount + amount
        }
      };
      case null {
        {
          owner = owner;
          farmId = farmId;
          amount = amount;
        }
      };
    };
    ledger.put(key, holder);
    #ok(holder)
  };

  // Transfer tokens from one principal to another
  public func transferTokens(
    from: Principal,
    to: Principal,
    farmId: Text,
    amount: Nat,
    ledger: TokenLedger,
    history: TransactionHistory
  ) : Result<Transaction> {
    let fromKey = farmId # Principal.toText(from);
    let toKey = farmId # Principal.toText(to);

    let fromHolder = switch (ledger.get(fromKey)) {
      case (?h) h;
      case null #err("Sender does not have any tokens for this farm");
    };

    if (fromHolder.amount < amount) {
      return #err("Insufficient balance");
    };

    let toHolder = switch (ledger.get(toKey)) {
      case (?h) {
        {
          ...h,
          amount = h.amount + amount
        }
      };
      case null {
        {
          owner = to;
          farmId = farmId;
          amount = amount;
        }
      };
    };

    let updatedFromHolder = {
      ...fromHolder,
      amount = fromHolder.amount - amount
    };

    ledger.put(fromKey, updatedFromHolder);
    ledger.put(toKey, toHolder);

    let transactionId = "txn-" # Int.toText(Time.now());
    let transaction: Transaction = {
      transactionId = transactionId;
      from = from;
      to = to;
      farmId = farmId;
      amount = amount;
      timestamp = Time.now();
    };
    history.put(transactionId, transaction);

    #ok(transaction)
  };

  // Get the token balance for a specific holder and farm
  public func getBalance(
    owner: Principal,
    farmId: Text,
    ledger: TokenLedger
  ) : Nat {
    let key = farmId # Principal.toText(owner);
    switch (ledger.get(key)) {
      case (?h) h.amount;
      case null 0;
    }
  };

  // Get all token holders for a specific farm
  public func getTokenHolders(
    farmId: Text,
    ledger: TokenLedger
  ) : [TokenHolder] {
    let holders = Iter.filter<(Text, TokenHolder)>(
      ledger.entries(),
      func ((_, holder)) = holder.farmId == farmId
    );
    Iter.toArray(
      Iter.map<(Text, TokenHolder), TokenHolder>(
        holders,
        func ((_, holder)) = holder
      )
    )
  };
}