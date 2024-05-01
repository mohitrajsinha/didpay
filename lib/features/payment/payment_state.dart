import 'package:didpay/features/home/transaction.dart';
import 'package:tbdex/tbdex.dart';

class PaymentState {
  final String payoutAmount;
  final String payinCurrency;
  final String payoutCurrency;
  final String exchangeRate;
  final String? serviceFee;
  final String? paymentName;
  final TransactionType transactionType;
  final List<PayinMethod>? payinMethods;
  final List<PayoutMethod>? payoutMethods;
  final Map<String, String>? formData;

  const PaymentState({
    required this.payoutAmount,
    required this.payinCurrency,
    required this.payoutCurrency,
    required this.exchangeRate,
    required this.transactionType,
    this.serviceFee,
    this.paymentName,
    this.payinMethods,
    this.payoutMethods,
    this.formData,
  });

  PaymentState copyWith({
    String? payoutAmount,
    String? payinCurrency,
    String? payoutCurrency,
    String? exchangeRate,
    String? serviceFee,
    String? paymentName,
    TransactionType? transactionType,
    List<PayinMethod>? payinMethods,
    List<PayoutMethod>? payoutMethods,
    Map<String, String>? formData,
  }) {
    return PaymentState(
      payoutAmount: payoutAmount ?? this.payoutAmount,
      payinCurrency: payinCurrency ?? this.payinCurrency,
      payoutCurrency: payoutCurrency ?? this.payoutCurrency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      serviceFee: serviceFee ?? this.serviceFee,
      paymentName: paymentName ?? this.paymentName,
      transactionType: transactionType ?? this.transactionType,
      payinMethods: payinMethods ?? this.payinMethods,
      payoutMethods: payoutMethods ?? this.payoutMethods,
      formData: formData ?? this.formData,
    );
  }
}