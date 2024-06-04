import 'package:collection/collection.dart';
import 'package:didpay/features/did/did_provider.dart';
import 'package:didpay/features/kcc/kcc_consent_page.dart';
import 'package:didpay/features/payment/payment_method_operations.dart';
import 'package:didpay/features/payment/payment_methods_page.dart';
import 'package:didpay/features/payment/payment_review_page.dart';
import 'package:didpay/features/payment/payment_state.dart';
import 'package:didpay/features/payment/payment_types_page.dart';
import 'package:didpay/features/tbdex/tbdex_service.dart';
import 'package:didpay/features/transaction/transaction.dart';
import 'package:didpay/features/vcs/vcs_notifier.dart';
import 'package:didpay/l10n/app_localizations.dart';
import 'package:didpay/shared/async/async_error_widget.dart';
import 'package:didpay/shared/async/async_loading_widget.dart';
import 'package:didpay/shared/header.dart';
import 'package:didpay/shared/json_schema_form.dart';
import 'package:didpay/shared/modal_flow.dart';
import 'package:didpay/shared/theme/grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tbdex/tbdex.dart';

class PaymentDetailsPage extends HookConsumerWidget {
  final PaymentState paymentState;

  const PaymentDetailsPage({
    required this.paymentState,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPaymentMethod = useState<Object?>(null);
    final selectedPaymentType = useState<String?>(null);
    final offeringCredentials = useState<List<String>?>(null);
    final rfqResponse = useState<AsyncValue<Rfq>?>(null);

    final paymentMethods = _getPaymentMethods(paymentState);
    final paymentTypes = _getPaymentTypes(paymentMethods);
    final filteredPaymentMethods =
        _getFilteredPaymentMethods(paymentMethods, selectedPaymentType.value);

    useEffect(
      () {
        selectedPaymentMethod.value = (filteredPaymentMethods?.length ?? 1) <= 1
            ? filteredPaymentMethods?.firstOrNull
            : null;
        return;
      },
      [selectedPaymentType.value],
    );

    final shouldShowPaymentTypeSelector = (paymentTypes.length) > 1;
    final shouldShowPaymentMethodSelector =
        !shouldShowPaymentTypeSelector || selectedPaymentType.value != null;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: rfqResponse.value != null
            ? rfqResponse.value!.when(
                data: (rfq) => AsyncLoadingWidget(
                  text: Loc.of(context).gettingYourQuote,
                ),
                loading: () => AsyncLoadingWidget(
                  text: Loc.of(context).sendingYourRequest,
                ),
                error: (error, _) => AsyncErrorWidget(
                  text: error.toString(),
                  onRetry: () => _sendRfq(
                    context,
                    ref,
                    paymentState,
                    rfqResponse,
                    claims: offeringCredentials.value,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Header(
                    title: paymentState.transactionType == TransactionType.send
                        ? Loc.of(context).enterTheirPaymentDetails
                        : Loc.of(context).enterYourPaymentDetails,
                    subtitle: Loc.of(context).makeSureInfoIsCorrect,
                  ),
                  if (shouldShowPaymentTypeSelector)
                    _buildPaymentTypeSelector(
                      context,
                      selectedPaymentType,
                      paymentTypes,
                    ),
                  if (shouldShowPaymentMethodSelector)
                    _buildPaymentMethodSelector(
                      context,
                      selectedPaymentMethod,
                      filteredPaymentMethods,
                    ),
                  _buildPaymentForm(
                    context,
                    paymentState.copyWith(
                      selectedPayinMethod: paymentState.transactionType ==
                              TransactionType.deposit
                          ? selectedPaymentMethod.value as PayinMethod?
                          : paymentState.payinMethods?.firstOrNull,
                      selectedPayoutMethod: paymentState.transactionType ==
                              TransactionType.withdraw
                          ? selectedPaymentMethod.value as PayoutMethod?
                          : paymentState.payoutMethods?.firstOrNull,
                    ),
                    onPaymentFormSubmit: (paymentState) async {
                      await _getVc(
                        context,
                        ref,
                        paymentState,
                        offeringCredentials,
                      ).then((_) {
                        _sendRfq(
                          context,
                          ref,
                          paymentState,
                          rfqResponse,
                          claims: offeringCredentials.value,
                        );
                      });
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPaymentForm(
    BuildContext context,
    PaymentState paymentState, {
    required void Function(PaymentState) onPaymentFormSubmit,
  }) {
    final paymentMethod =
        paymentState.transactionType == TransactionType.deposit
            ? paymentState.selectedPayinMethod
            : paymentState.selectedPayoutMethod;

    final isDisabled = paymentMethod.isDisabled;
    final schema = paymentMethod.paymentSchema;
    final fee = paymentMethod.paymentFee;
    final paymentName = paymentMethod.paymentName;

    return Expanded(
      child: JsonSchemaForm(
        schema: schema,
        isDisabled: isDisabled,
        onSubmit: (formData) => onPaymentFormSubmit(
          paymentState.copyWith(
            serviceFee: fee,
            paymentName: paymentName,
            formData: formData,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTypeSelector(
    BuildContext context,
    ValueNotifier<String?> selectedPaymentType,
    Set<String> paymentTypes,
  ) =>
      Column(
        children: [
          const SizedBox(height: Grid.xxs),
          ListTile(
            title: Text(
              selectedPaymentType.value == null
                  ? Loc.of(context).selectPaymentType
                  : selectedPaymentType.value ?? '',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaymentTypesPage(
                    payinCurrency: paymentState.payinCurrency,
                    paymentTypes: paymentTypes,
                    selectedPaymentType: selectedPaymentType,
                  ),
                ),
              );
            },
          ),
        ],
      );

  Widget _buildPaymentMethodSelector(
    BuildContext context,
    ValueNotifier<Object?> selectedPaymentMethod,
    List<Object?>? filteredPaymentMethods,
  ) {
    final isSelectionDisabled = (filteredPaymentMethods?.length ?? 0) <= 1;
    final fee = double.tryParse(
          selectedPaymentMethod.value?.paymentFee ?? '0.00',
        )?.toStringAsFixed(2) ??
        '0.00';

    if (isSelectionDisabled) {
      selectedPaymentMethod.value = filteredPaymentMethods?.firstOrNull;
    }

    return Column(
      children: [
        const SizedBox(height: Grid.xxs),
        ListTile(
          title: Text(
            selectedPaymentMethod.value.paymentName ??
                Loc.of(context).selectPaymentMethod,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          subtitle: Text(
            selectedPaymentMethod.value.paymentName == null
                ? Loc.of(context).serviceFeesMayApply
                : Loc.of(context)
                    .serviceFeeAmount(fee, paymentState.payinCurrency ?? ''),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing:
              isSelectionDisabled ? null : const Icon(Icons.chevron_right),
          onTap: isSelectionDisabled
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PaymentMethodsPage(
                        paymentCurrency: paymentState.transactionType ==
                                TransactionType.deposit
                            ? paymentState.payinCurrency
                            : paymentState.payoutCurrency,
                        selectedPaymentMethod: selectedPaymentMethod,
                        paymentMethods: filteredPaymentMethods,
                      ),
                    ),
                  );
                },
        ),
      ],
    );
  }

  List<Object?>? _getPaymentMethods(PaymentState paymentState) =>
      paymentState.transactionType == TransactionType.deposit
          ? paymentState.payinMethods
          : paymentState.payoutMethods;

  Set<String> _getPaymentTypes(List<Object?>? paymentMethods) =>
      paymentMethods
          ?.map((method) => method.paymentGroup)
          .whereType<String>()
          .toSet() ??
      {};

  List<Object?>? _getFilteredPaymentMethods(
    List<Object?>? paymentMethods,
    String? selectedPaymentType,
  ) =>
      paymentMethods
          ?.where(
            (method) =>
                method.paymentGroup?.contains(selectedPaymentType ?? '') ??
                true,
          )
          .toList();

  void _sendRfq(
    BuildContext context,
    WidgetRef ref,
    PaymentState paymentState,
    ValueNotifier<AsyncValue<Rfq>?> state, {
    List<String>? claims,
  }) {
    state.value = const AsyncLoading();
    ref
        .read(tbdexServiceProvider)
        .sendRfq(
          ref.read(didProvider),
          paymentState.copyWith(claims: claims),
        )
        .then((rfq) async {
      state.value = AsyncData(rfq);
      await Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => PaymentReviewPage(
                paymentState: paymentState.copyWith(
                  exchangeId: rfq.metadata.id,
                  claims: claims,
                ),
              ),
            ),
          )
          .then((_) => state.value = null);
    }).catchError((error, stackTrace) {
      state.value = AsyncError(error.toString(), stackTrace);
      throw error;
    });
  }

  Future<void> _getVc(
    BuildContext context,
    WidgetRef ref,
    PaymentState paymentState,
    ValueNotifier<List<String>?> offeringCredentials,
  ) async {
    final presentationDefinition =
        paymentState.selectedOffering?.data.requiredClaims;
    final credentials =
        presentationDefinition?.selectCredentials(ref.read(vcsProvider));

    if (credentials != null && credentials.isNotEmpty) {
      offeringCredentials.value = credentials;
    } else if (presentationDefinition != null) {
      final issuedCredential = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ModalFlow(
            initialWidget: KccConsentPage(pfi: paymentState.selectedPfi!),
          ),
          fullscreenDialog: true,
        ),
      );

      issuedCredential == null
          ? offeringCredentials.value = null
          : offeringCredentials.value = [issuedCredential as String];
    } else {
      offeringCredentials.value = null;
    }
  }
}