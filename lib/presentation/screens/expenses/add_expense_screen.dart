import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../router/app_router.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String projectId;

  const AddExpenseScreen({super.key, required this.projectId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _paidAmountController = TextEditingController();

  String _selectedCategory = ExpenseCategories.materials;
  String _selectedPaymentMethod = PaymentMethods.cash;
  String _selectedPaymentStatus = PaymentStatus.paid;
  DateTime _expenseDate = DateTime.now();
  File? _receiptImage;
  bool _isLoading = false;

  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: AppConstants.maxImageWidth.toDouble(),
        maxHeight: AppConstants.maxImageHeight.toDouble(),
        imageQuality: AppConstants.imageQuality,
      );

      if (pickedFile != null) {
        setState(() {
          _receiptImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.uploadReceipt,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceOption(
                    context,
                    icon: Icons.camera_alt,
                    label: AppStrings.takePhoto,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: _buildImageSourceOption(
                    context,
                    icon: Icons.photo_library,
                    label: AppStrings.chooseFromGallery,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate paid amount for partial payment
    if (_selectedPaymentStatus == PaymentStatus.partial) {
      final paidText = _paidAmountController.text.replaceAll(',', '');
      final totalAmount = double.parse(
        _amountController.text.replaceAll(',', ''),
      );
      final paidAmount = double.tryParse(paidText) ?? 0;

      if (paidAmount <= 0 || paidAmount >= totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paid amount must be between 0 and total amount'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authNotifierProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);
      final projectAsync = ref.read(projectProvider(widget.projectId));

      final project = projectAsync.value;

      // Only admin can auto-approve expenses - directors and labour must get admin approval
      final isAdmin = project != null && 
          project.isUserAdmin(authState.user!.id);

      // Convert receipt image to Base64 and store directly in Firestore
      String? receiptUrl;
      if (_receiptImage != null) {
        try {
          print('Converting receipt image to Base64...');
          final bytes = await _receiptImage!.readAsBytes();
          
          // Check file size (limit to ~500KB for Firestore)
          if (bytes.length > 500 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image is too large. Please use a smaller image (max 500KB).'),
                  backgroundColor: AppColors.warning,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else {
            // Determine mime type from file extension
            final extension = _receiptImage!.path.toLowerCase();
            String mimeType = 'image/jpeg';
            if (extension.endsWith('.png')) {
              mimeType = 'image/png';
            } else if (extension.endsWith('.gif')) {
              mimeType = 'image/gif';
            } else if (extension.endsWith('.webp')) {
              mimeType = 'image/webp';
            }
            
            // Convert to Base64 data URI
            final base64String = base64Encode(bytes);
            receiptUrl = 'data:$mimeType;base64,$base64String';
            print('Receipt converted to Base64 successfully (${bytes.length} bytes)');
          }
        } catch (e) {
          print('Error converting image to Base64: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to process receipt image: $e'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        print('No receipt image selected');
      }

      final amount = double.parse(_amountController.text.replaceAll(',', ''));
      final paidAmount = _selectedPaymentStatus == PaymentStatus.partial
          ? double.parse(_paidAmountController.text.replaceAll(',', ''))
          : _selectedPaymentStatus == PaymentStatus.paid
          ? amount
          : 0.0;

      final expense = await expenseRepo.createExpense(
        projectId: widget.projectId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        amount: amount,
        category: _selectedCategory,
        paymentMethod: _selectedPaymentMethod,
        paymentStatus: _selectedPaymentStatus,
        paidAmount: paidAmount,
        receiptUrl: receiptUrl,
        createdBy: authState.user!.id,
        createdByName: authState.user!.name,
        expenseDate: _expenseDate,
        isAdmin: isAdmin, // Auto-approve if admin
      );

      // Send notification to admin and all directors (except creator) if user is NOT admin
      if (project != null && !isAdmin) {
        // Get all director user IDs
        final directorUserIds = project.members
            .where((m) => m.isDirector)
            .map((m) => m.userId)
            .toList();

        await NotificationService.instance.notifyAdminExpenseCreated(
          adminId: project.adminId,
          projectName: project.name,
          expenseTitle: expense.title,
          amount: expense.amount,
          createdByName: authState.user!.name,
          createdByUserId: authState.user!.id,
          projectId: widget.projectId,
          expenseId: expense.id,
          directorUserIds: directorUserIds,
        );
      }

      ref.invalidate(projectExpensesProvider(widget.projectId));
      ref.invalidate(projectProvider(widget.projectId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('${AppRoutes.projects}/${widget.projectId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add expense: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectAsync = ref.watch(projectProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.addExpense)),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('Project not found'));
          }

          final authState = ref.watch(authNotifierProvider);
          final userId = authState.user?.id ?? '';
          final canSeeDetails = project.canUserSeeDetails(userId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project info
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder, color: theme.colorScheme.primary),
                        const SizedBox(width: AppTheme.spaceSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Only show remaining budget if user can see details (admin/director)
                              if (canSeeDetails)
                                Text(
                                  'Remaining: ${Formatters.formatCurrency(project.remainingBudget)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  // Title
                  CustomTextField(
                    label: AppStrings.expenseTitle,
                    hint: 'e.g., Cement Purchase',
                    controller: _titleController,
                    prefixIcon: const Icon(Icons.title),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        Validators.validateRequired(value, 'Title'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Amount
                  CustomTextField(
                    label: AppStrings.amount,
                    hint: 'Enter amount',
                    controller: _amountController,
                    prefixIcon: const Icon(Icons.attach_money),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandsSeparatorFormatter(),
                    ],
                    validator: Validators.validateAmount,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Category
                  _buildDropdownField(
                    context,
                    label: AppStrings.category,
                    value: _selectedCategory,
                    items: ExpenseCategories.all,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                    itemBuilder: (category) => Row(
                      children: [
                        Text(
                          ExpenseCategories.icons[category] ?? '📦',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                        Text(category),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Payment method
                  _buildDropdownField(
                    context,
                    label: AppStrings.paymentMethod,
                    value: _selectedPaymentMethod,
                    items: PaymentMethods.all,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPaymentMethod = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Payment status
                  _buildPaymentStatusSection(context),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Date
                  _buildDateField(context),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Description
                  CustomTextField(
                    label: '${AppStrings.description} (Optional)',
                    hint: 'Add any additional details...',
                    controller: _descriptionController,
                    prefixIcon: const Icon(Icons.description),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Receipt
                  _buildReceiptSection(context),
                  const SizedBox(height: AppTheme.spaceXl),
                  // Submit button
                  PrimaryButton(
                    text: AppStrings.addExpense,
                    onPressed: _handleSubmit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load project')),
      ),
    );
  }

  Widget _buildDropdownField<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    Widget Function(T)? itemBuilder,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: itemBuilder != null
                      ? itemBuilder(item)
                      : Text(item.toString()),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatusSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Status',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        // Payment status chips
        Wrap(
          spacing: AppTheme.spaceSm,
          children: PaymentStatus.all.map((status) {
            final isSelected = _selectedPaymentStatus == status;
            final color = status == PaymentStatus.paid
                ? AppColors.success
                : status == PaymentStatus.credit
                ? AppColors.warning
                : AppColors.tertiary;

            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    PaymentStatus.icons[status] ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  Text(PaymentStatus.labels[status] ?? status),
                ],
              ),
              selected: isSelected,
              selectedColor: color.withValues(alpha: 0.2),
              checkmarkColor: color,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedPaymentStatus = status;
                    // Clear paid amount when switching
                    if (status != PaymentStatus.partial) {
                      _paidAmountController.clear();
                    }
                  });
                }
              },
            );
          }).toList(),
        ),
        // Show paid amount field for partial payment
        if (_selectedPaymentStatus == PaymentStatus.partial) ...[
          const SizedBox(height: AppTheme.spaceMd),
          CustomTextField(
            label: 'Paid Amount',
            hint: 'Enter amount paid',
            controller: _paidAmountController,
            prefixIcon: const Icon(Icons.payments),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _ThousandsSeparatorFormatter(),
            ],
            validator: (value) {
              if (_selectedPaymentStatus == PaymentStatus.partial) {
                if (value == null || value.isEmpty) {
                  return 'Please enter paid amount';
                }
                final paidAmount =
                    double.tryParse(value.replaceAll(',', '')) ?? 0;
                if (paidAmount <= 0) {
                  return 'Amount must be greater than 0';
                }
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          if (_amountController.text.isNotEmpty &&
              _paidAmountController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spaceXs),
              child: Builder(
                builder: (context) {
                  final total =
                      double.tryParse(
                        _amountController.text.replaceAll(',', ''),
                      ) ??
                      0;
                  final paid =
                      double.tryParse(
                        _paidAmountController.text.replaceAll(',', ''),
                      ) ??
                      0;
                  final pending = total - paid;

                  return Container(
                    padding: const EdgeInsets.all(AppTheme.spaceSm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppTheme.spaceXs),
                        Text(
                          'Pending: ${Formatters.formatCurrency(pending > 0 ? pending : 0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
        // Info text for credit
        if (_selectedPaymentStatus == PaymentStatus.credit)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spaceSm),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppTheme.spaceXs),
                  Expanded(
                    child: Text(
                      'Payment is pending. You can mark it as paid later.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expense Date',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: theme.inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: AppTheme.spaceMd),
                Text(
                  Formatters.formatDate(_expenseDate),
                  style: theme.textTheme.bodyLarge,
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppStrings.receipt} (Optional)',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        if (_receiptImage != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Image.file(
                  _receiptImage!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _receiptImage = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(
                    AppStrings.uploadReceipt,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final newText = newValue.text.replaceAll(',', '');
    final buffer = StringBuffer();

    for (int i = 0; i < newText.length; i++) {
      if (i > 0 && (newText.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(newText[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
