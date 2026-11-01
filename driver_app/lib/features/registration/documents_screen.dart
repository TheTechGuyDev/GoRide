import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/routes.dart';
import 'registration_controller.dart';

/// Status chip used for documents everywhere.
class DocStatusChip extends StatelessWidget {
  const DocStatusChip({super.key, required this.doc});
  final DriverDocument doc;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (doc.status) {
      DocStatus.missing => ('Not uploaded', AppColors.textHint),
      DocStatus.inReview => ('In review', const Color(0xFF2196F3)),
      DocStatus.rejected => ('Needs attention', AppColors.error),
      DocStatus.approved when doc.isExpired => ('Expired', AppColors.error),
      DocStatus.approved when doc.expiresSoon => (
        'Expires soon',
        AppColors.warning,
      ),
      DocStatus.approved => ('Approved', AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// List of required documents (registration and Account > Documents).
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key, this.fromAccount = false});
  final bool fromAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(registrationProvider);
    final docs = reg.requiredDocs.map(reg.doc).toList();
    final needsAction = docs
        .where(
          (d) => d.status == DocStatus.rejected || d.isExpired || d.expiresSoon,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (!fromAccount)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Upload clear photos. All four corners must be visible and the text readable.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ),
          if (fromAccount && needsAction.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${needsAction.length} document${needsAction.length == 1 ? '' : 's'} need${needsAction.length == 1 ? 's' : ''} updating. Expired documents stop you from going online.',
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          for (final d in docs)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(
                  color: d.status == DocStatus.rejected
                      ? AppColors.error
                      : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                onTap: () => context.push(Routes.regDocumentFor(d.type.name)),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(d.type.icon, color: AppColors.primary),
                ),
                title: Text(
                  d.type.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      DocStatusChip(doc: d),
                      if (d.expiry != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Exp. ${formatDate(d.expiry!)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
      ),
      bottomNavigationBar: fromAccount
          ? null
          : BottomActionBar(
              child: AppButton(
                label: reg.docsComplete ? 'Done' : 'Save and continue later',
                onPressed: () => context.pop(),
              ),
            ),
    );
  }
}

/// Upload or replace one document.
class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({super.key, required this.type});
  final DocType type;

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  Uint8List? _image;
  late final TextEditingController _number;
  DateTime? _expiry;
  bool _saving = false;
  late final DriverDocument _existing;

  @override
  void initState() {
    super.initState();
    _existing = ref.read(registrationProvider).doc(widget.type);
    _image = _existing.image;
    _number = TextEditingController(text: _existing.number);
    _expiry = _existing.expiry;
  }

  bool get _hasImage => _image != null || _existing.uploaded;

  bool get _valid {
    final t = widget.type;
    if (!_hasImage) return false;
    if (t.expires && _expiry == null) return false;
    if (t == DocType.nin && _number.text.length != 11) return false;
    if (t.numberLabel != null && _number.text.trim().length < 5) return false;
    return true;
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _image = bytes);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry != null && _expiry!.isAfter(now)
          ? _expiry!
          : now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'Expiry date',
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Later: upload to Supabase Storage (driver-documents bucket).
    await Future.delayed(const Duration(milliseconds: 900));
    ref
        .read(registrationProvider.notifier)
        .saveDocument(
          DriverDocument(
            type: widget.type,
            image: _image,
            number: _number.text.trim(),
            expiry: _expiry,
            status: DocStatus.inReview,
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${widget.type.title} uploaded')));
    context.pop();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.type;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            t.hint,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          if (_existing.status == DocStatus.rejected &&
              _existing.note != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_existing.note!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.6,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () =>
                  _pick(kIsWeb ? ImageSource.gallery : ImageSource.camera),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: _image != null
                    ? Image.memory(_image!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _existing.uploaded
                                ? Icons.check_circle
                                : Icons.add_a_photo_outlined,
                            size: 44,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _existing.uploaded
                                ? 'Uploaded. Tap to replace'
                                : 'Tap to take a photo',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!kIsWeb)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              if (!kIsWeb) const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from gallery'),
                ),
              ),
            ],
          ),
          if (t.numberLabel != null) ...[
            const SizedBox(height: 24),
            FieldLabel(t.numberLabel!),
            TextField(
              controller: _number,
              onChanged: (_) => setState(() {}),
              keyboardType: t == DocType.nin
                  ? TextInputType.number
                  : TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: t == DocType.nin
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ]
                  : null,
              decoration: InputDecoration(
                hintText: t == DocType.nin ? '11-digit NIN' : t.numberLabel,
              ),
            ),
          ],
          if (t.expires) ...[
            const SizedBox(height: 20),
            const FieldLabel('Expiry date'),
            InkWell(
              onTap: _pickExpiry,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_month_outlined, size: 20),
                ),
                child: Text(
                  _expiry == null ? 'Select date' : formatDate(_expiry!),
                  style: TextStyle(
                    fontSize: 16,
                    color: _expiry == null ? AppColors.textHint : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll remind you 30 days before it expires.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: 'Upload',
          loading: _saving,
          onPressed: _valid ? _save : null,
        ),
      ),
    );
  }
}
