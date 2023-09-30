import 'package:get/get.dart';
import 'package:journal/models/Transaction.dart';

import '../models/TransactionTag.dart';
import '../repository/TransactionRepository.dart';
import '../service/TransactionService.dart';

class TransactionController extends GetxController {
  final TransactionRepository transactionRepository;

  TransactionController(this.transactionRepository);

  var transactionList = List<Transaction>.empty().obs;

  double get balance =>
      transactionList.fold(0, (sum, transaction) => sum + transaction.amount);

  double get income => transactionList.fold(0, (sum, transaction) {
        if (transaction.amount > 0) return sum + transaction.amount;
        return sum;
      });

  double get expense => transactionList.fold(0, (sum, transaction) {
        if (transaction.amount <= 0) return sum + transaction.amount;
        return sum;
      });

  @override
  void onInit() async {
    super.onInit();

    transactionList.value = await transactionRepository.getTransactions();
  }

  void insertRandomData() {
    TransactionService().getTransactionList().forEach((element) async {
      await transactionRepository.insertTransaction(element);
    });
  }

  Future<List<Transaction>> searchTransaction(String searchString) async {
    return await transactionRepository.getTransactionsRawQuery('''
    SELECT * FROM tableName
    WHERE description LIKE ?
  ''', ['%$searchString%']);
  }

  Future<List<Transaction>> getTransactionsBetweenDates({
    DateTime? startDate, // older date
    DateTime? endDate,  // newer date
    required Set<TransactionTag>? tagSet,
  }) async {
    if (startDate == null || endDate == null) {
      return await transactionRepository.getTransactions();
    }

    // this is done since we are fetching data between these two dates included
    startDate = startDate.add(Duration(days: -1));
    endDate = endDate.add(Duration(days: 1));

    List<Transaction> transactions =
        await transactionRepository.getTransactionsRawQuery('''
    SELECT * FROM tableName
    WHERE date BETWEEN ? AND ?
  ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    if (tagSet == null || tagSet.isEmpty) {
      return transactions;
    }
    return transactions
        .where((transaction) =>
            tagSet.contains(TransactionTag.getTagById(transaction.tag)))
        .toList();
  }

  void deleteTransaction(Transaction transaction) async {
    await transactionRepository.deleteTransaction(transaction.id!);
    transactionList.removeWhere((item) => item.id == transaction.id);
    refreshTransactionList();
  }

  void deleteAllTransactions() async {
    await transactionRepository.deleteAllTransactions();
    transactionList.value = await transactionRepository.getTransactions();
    refreshTransactionList();
  }

  void addTransaction(Transaction transaction) async {
    transaction.setAmount(transaction.amount);
    transaction.id = await transactionRepository.insertTransaction(transaction);

    int existingIndex =
        transactionList.indexWhere((existing) => existing.id == transaction.id);

    if (existingIndex != -1) {
      transactionList.removeAt(existingIndex);
    }
    transactionList.add(transaction);
    refreshTransactionList();
  }

  void refreshTransactionList() {
    transactionList.sort((a, b) => b.date.compareTo(a.date));
    transactionList.refresh();
  }
}
