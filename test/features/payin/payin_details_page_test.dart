import 'dart:convert';

import 'package:didpay/features/home/transaction.dart';
import 'package:didpay/features/payin/payin_details_page.dart';
import 'package:didpay/features/payin/search_payin_methods_page.dart';
import 'package:didpay/features/payment/search_payment_types_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';
import 'package:tbdex/tbdex.dart';

import '../../helpers/widget_helpers.dart';

void main() {
  group('PayinDetailsPage', () {
    final schema = JsonSchema.create(
      jsonDecode(r'''
        {
          "$schema": "http://json-schema.org/draft-07/schema#",
          "type": "object",
          "properties": {
            "cardNumber": {
              "type": "string",
              "title": "Card number",
              "description": "The 16-digit debit card number",
              "minLength": 16,
              "maxLength": 16
            },
            "expiryDate": {
              "type": "string",
              "description": "The expiry date of the card in MM/YY format",
              "pattern": "^(0[1-9]|1[0-2])\\/([0-9]{2})$"
            },
            "cardHolderName": {
              "type": "string",
              "description": "Name of the cardholder as it appears on the card"
            },
            "cvv": {
              "type": "string",
              "description": "The 3-digit CVV code",
              "minLength": 3,
              "maxLength": 3
            }
          },
          "required": ["cardNumber", "expiryDate", "cardHolderName", "cvv"],
          "additionalProperties": false
        }
    '''),
    );

    Widget paymentDetailsPageTestWidget({
      List<PayinMethod> payinMethods = const [],
    }) =>
        WidgetHelpers.testableWidget(
          child: PayinDetailsPage(
            payinAmount: '1.00',
            payinCurrency: 'USD',
            exchangeRate: '17',
            payoutAmount: '17.00',
            payoutCurrency: 'MXN',
            offeringId: '',
            transactionType: TransactionType.deposit,
            payinMethods: payinMethods,
          ),
        );

    testWidgets('should show header', (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(child: paymentDetailsPageTestWidget()),
      );

      expect(find.text('Enter your payment details'), findsOneWidget);
      expect(
        find.text('Make sure this information is correct.'),
        findsOneWidget,
      );
    });

    testWidgets('should show payment type selection zero state',
        (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(
          child: paymentDetailsPageTestWidget(
            payinMethods: [
              PayinMethod(
                kind: 'MOMO_MPESA',
                name: 'M-Pesa',
                group: 'Mobile money',
              ),
              PayinMethod(
                kind: 'BANK_GT BANK',
                name: 'GT Bank',
                group: 'Bank',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Select a payment type'), findsOneWidget);
    });

    testWidgets('should not show payment type selector', (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(
          child: paymentDetailsPageTestWidget(
            payinMethods: [
              PayinMethod(
                kind: 'MOMO_MPESA',
                name: 'M-Pesa',
                group: 'Mobile money',
              ),
              PayinMethod(
                kind: 'MOMO_MTN',
                name: 'MTN',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Select a payment type'), findsNothing);
    });

    testWidgets('should show payin method selection zero state',
        (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(
          child: paymentDetailsPageTestWidget(
            payinMethods: [
              PayinMethod(
                kind: 'MOMO_MPESA',
                name: 'M-Pesa',
              ),
              PayinMethod(
                kind: 'MOMO_MTN',
                name: 'MTN',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Select a payment method'), findsOneWidget);
      expect(find.text('Service fees may apply'), findsOneWidget);
    });

    testWidgets('should show payin method without selector', (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(
          child: paymentDetailsPageTestWidget(
            payinMethods: [
              PayinMethod(
                kind: 'MOMO_MPESA',
                name: 'M-Pesa',
              ),
            ],
          ),
        ),
      );

      expect(find.widgetWithText(ListTile, 'M-Pesa'), findsOneWidget);
      expect(find.widgetWithIcon(Icon, Icons.chevron_right), findsNothing);
    });

    testWidgets(
        'should show SearchPaymentTypesPage on tap of select a payment type',
        (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(
          child: paymentDetailsPageTestWidget(
            payinMethods: [
              PayinMethod(
                kind: 'MOMO_MPESA',
                name: 'M-Pesa',
                group: 'Mobile money',
              ),
              PayinMethod(
                kind: 'BANK_GT BANK',
                name: 'GT Bank',
                group: 'Bank',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Select a payment type'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPaymentTypesPage), findsOneWidget);
    });

    testWidgets(
        'should show SearchPayinMethodsPage on tap of select a payment method',
        (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(
          child: paymentDetailsPageTestWidget(
            payinMethods: [
              PayinMethod(
                kind: 'MOMO_MPESA',
                name: 'M-Pesa',
              ),
              PayinMethod(
                kind: 'MOMO_MTN',
                name: 'MTN',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Select a payment method'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPayinMethodsPage), findsOneWidget);
    });

    testWidgets(
        'should show payment type after SearchPaymentTypesPage selection',
        (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(
          child: paymentDetailsPageTestWidget(
            payinMethods: [
              PayinMethod(
                kind: 'MOMO_MPESA',
                name: 'M-Pesa',
                group: 'Mobile money',
              ),
              PayinMethod(
                kind: 'BANK_GT BANK',
                name: 'GT Bank',
                group: 'Bank',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Select a payment type'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bank'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Bank'), findsOneWidget);
    });

    testWidgets(
        'should show payment name after SearchPayinMethodsPage selection',
        (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(
          child: paymentDetailsPageTestWidget(
            payinMethods: [
              PayinMethod(
                kind: 'MOMO_MPESA',
                name: 'M-Pesa',
              ),
              PayinMethod(
                kind: 'BANK_GT BANK',
                name: 'GT Bank',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Select a payment method'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('M-Pesa'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'M-Pesa'), findsOneWidget);
    });

    testWidgets('should show schema form', (tester) async {
      await tester.pumpWidget(
        WidgetHelpers.testableWidget(
          child: paymentDetailsPageTestWidget(
            payinMethods: [
              PayinMethod(
                kind: 'MOMO_MPESA',
                name: 'M-Pesa',
                requiredPaymentDetails: schema,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(TextFormField), findsExactly(4));
      expect(find.text('Card number'), findsOneWidget);
      expect(find.text('expiryDate'), findsOneWidget);
      expect(find.text('cardHolderName'), findsOneWidget);
      expect(find.text('cvv'), findsOneWidget);
    });
  });
}
