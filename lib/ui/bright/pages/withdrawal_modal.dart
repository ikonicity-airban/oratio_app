import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ace_toast/ace_toast.dart';
import 'package:oratio_app/bloc/auth_bloc/cubit/pocket_base_service_cubit.dart';
import 'package:pocketbase/pocketbase.dart';

class WithdrawalModal extends StatefulWidget {
  const WithdrawalModal({super.key, required this.banks, required this.parish});
  final List banks;
  final RecordModel parish;
  @override
  _WithdrawalModalState createState() =>
      _WithdrawalModalState(parish, bankNames: banks);
}

class _WithdrawalModalState extends State<WithdrawalModal> {
  // Bank selection dropdown values
  final List _bankNames;
  String? _selectedBank;
  final RecordModel parish;
  // Text controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();

  // State for loading
  bool _isLoading = false;

  // Data map to hold withdrawal details
  Map<String, dynamic> data = {};

  _WithdrawalModalState(this.parish, {required List bankNames})
      : _bankNames = bankNames;

  Future<void> submitWithdrawalRequest(Map<String, dynamic> data) async {
    final pb = context.read<PocketBaseServiceCubit>().state.pb;
    data['user'] = pb.authStore.model.id;
    await pb.collection("withdrawal_request").create(body: data);
  }

  void _submitWithdrawal() async {
    // Validation logic
    if (_amountController.text.isEmpty) {
      _showValidationError('Please enter a withdrawal amount');
      return;
    }

    if (_accountController.text.isEmpty) {
      _showValidationError('Please enter an account number');
      return;
    }

    if (_selectedBank == null) {
      _showValidationError('Please select a bank');
      return;
    }

    final amt = int.tryParse(_amountController.text.trim());
    if (amt == null) {
      return _showValidationError(
          "Invalid amount typed in, make sure amount is in digits");
    }
    if (amt > parish.getIntValue('wallet')) {
      return _showValidationError("Insufficient Balance in parish account");
    }

    // Prepare data map
    data = {
      'amount': _amountController.text,
      'account_number': _accountController.text,
      'bank_name': _selectedBank,
    };

    // Set loading state
    setState(() {
      _isLoading = true;
    });
    try {
      // Simulate network request
      await submitWithdrawalRequest(data);

      NotificationService.showSuccess(
          'Withdrawal request for \$${data['amount']} submitted successfully!',
          duration: const Duration(seconds: 5));

      // Close the modal
      Navigator.of(context).pop();

      // Clear data
      _resetForm();
    } catch (e) {
      NotificationService.showError(
        "An Error occured submittin request,please confirm that you have up to the required amount or contact customer care",
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _amountController.clear();
      _accountController.clear();
      _selectedBank = null;
      data.clear();
    });
  }

  void _showValidationError(String message) {
    NotificationService.showError(message,
        duration: const Duration(seconds: 6));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header with Catholic-inspired design
                FadeIn(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.church_outlined,
                        color: Colors.deepPurple[700],
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Withdrawal Request',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple[900],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Amount Input
                FadeInRight(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Withdrawal Amount',
                      prefixIcon: Icon(Icons.monetization_on,
                          color: Colors.deepPurple[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      hintText: 'Enter amount',
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Account Number Input
                FadeInRight(
                  child: TextField(
                    controller: _accountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Account Number',
                      prefixIcon: Icon(Icons.account_balance,
                          color: Colors.deepPurple[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      hintText: 'Enter account number',
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Bank Dropdown
                FadeInRight(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBank,
                    hint: Text(
                      'Select Bank',
                      style: TextStyle(color: Colors.deepPurple[700]),
                    ),
                    decoration: InputDecoration(
                      constraints: const BoxConstraints(maxHeight: 400),
                      prefixIcon: Icon(Icons.account_balance_sharp,
                          color: Colors.deepPurple[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _bankNames.map((bank) {
                      return DropdownMenuItem<String>(
                        value: bank['slug'],
                        child: SizedBox(
                          width: 200,
                          child: Text(
                            bank['name'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedBank = newValue;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button with Loading State
                FadeInUp(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.deepPurple[700]!,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _submitWithdrawal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple[700],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Submit Request',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }
}
