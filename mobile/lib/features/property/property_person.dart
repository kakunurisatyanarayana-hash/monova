import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/contacts_picker.dart';
import '../../core/format.dart';
import '../../core/property_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../tools/contact_picker_sheet.dart';

bool _validPhone(String s) => s.replaceAll(RegExp(r'\D'), '').length >= 10;

/// Opens the phone's contacts and returns the one chosen, or null if nothing was picked.
Future<PickedContact?> pickOneContact(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final List<PickedContact> contacts;
  try {
    contacts = await loadContacts();
  } on ContactsException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Contacts could not be opened. Details: $e')));
    return null;
  }
  if (!context.mounted) return null;
  final picked = await FormSheet.show<List<PickedContact>>(
    context,
    title: 'Pick a contact',
    child: ContactPickerSheet(contacts: contacts, singleSelect: true),
  );
  if (picked == null || picked.isEmpty) return null;
  return picked.first;
}

/// Adds a person to the book, or replaces the one with the same id.
PropertyBook withPerson(PropertyBook book, Person p) => book.copyWith(
      persons: book.personById(p.id) == null
          ? [...book.persons, p]
          : [for (final x in book.persons) x.id == p.id ? p : x],
    );

/// The person form: name, mobile, address, emergency contact, and optional email and ID.
/// Everything except email and ID is required, so every person has complete contact details.
class PersonForm extends StatefulWidget {
  const PersonForm({
    super.key,
    this.initial,
    this.propertyId = '',
    this.role = 'Tenant',
    this.prefillName = '',
    this.prefillPhone = '',
  });

  final Person? initial;
  final String propertyId;
  final String role;
  final String prefillName;
  final String prefillPhone;

  @override
  State<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<PersonForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? widget.prefillName);
  late final _phone = TextEditingController(text: widget.initial?.phone ?? widget.prefillPhone);
  late final _email = TextEditingController(text: widget.initial?.email ?? '');
  late final _address = TextEditingController(text: widget.initial?.address ?? '');
  late final _emName = TextEditingController(text: widget.initial?.emergencyName ?? '');
  late final _emPhone = TextEditingController(text: widget.initial?.emergencyPhone ?? '');
  late final _idNumber = TextEditingController();
  late String _idType = widget.initial?.idType ?? '';
  late String _role = widget.initial?.role ?? widget.role;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _emName, _emPhone, _idNumber]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickContact() async {
    final c = await pickOneContact(context);
    if (c == null || !mounted) return;
    setState(() {
      _name.text = c.name;
      _phone.text = c.phone;
    });
  }

  void _save() {
    final name = _name.text.trim();
    String? problem;
    if (name.isEmpty) {
      problem = 'Enter the full name.';
    } else if (!_validPhone(_phone.text)) {
      problem = 'Enter a mobile number with at least 10 digits.';
    } else if (_address.text.trim().isEmpty) {
      problem = 'Enter the address.';
    } else if (_emName.text.trim().isEmpty || !_validPhone(_emPhone.text)) {
      problem = 'Enter an emergency contact name and a number with at least 10 digits.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final base = widget.initial;
    // Only the last four characters of an ID number are kept.
    final digits = _idNumber.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final last4 = digits.length <= 4 ? digits : digits.substring(digits.length - 4);
    Navigator.of(context).pop(Person(
      id: base?.id ?? PropertyStore.newId(),
      name: name,
      createdAt: base?.createdAt ?? DateTime.now(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      emergencyName: _emName.text.trim(),
      emergencyPhone: _emPhone.text.trim(),
      idType: _idType,
      idLast4: last4.isEmpty ? (base?.idLast4 ?? '') : last4,
      role: _role,
      propertyId: base?.propertyId ?? widget.propertyId,
      rating: base?.rating ?? 0,
      review: base?.review ?? '',
      notes: base?.notes ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.initial == null) ...[
          OutlinedButton.icon(
            onPressed: _pickContact,
            icon: const Icon(Icons.contacts_rounded, size: 18),
            label: const Text('Pick from contacts'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(controller: _name, autofocus: widget.initial == null, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name *')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number *')),
        const SizedBox(height: 12),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)')),
        const SizedBox(height: 12),
        TextField(controller: _address, textCapitalization: TextCapitalization.sentences, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Permanent address *')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _emName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Emergency contact name *'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _emPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Emergency number *'))),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _role,
          decoration: const InputDecoration(labelText: 'Role'),
          items: [for (final r in personRoles) DropdownMenuItem(value: r, child: Text(r))],
          onChanged: (v) => setState(() => _role = v ?? _role),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _idType,
                decoration: const InputDecoration(labelText: 'ID proof (optional)'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Not recorded')),
                  for (final t in idTypes) DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _idType = v ?? ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _idNumber,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'ID number',
                  helperText: widget.initial?.idLast4.isNotEmpty == true ? 'Saved: ····${widget.initial!.idLast4}' : 'Only the last 4 are kept',
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Save person' : 'Save changes')),
      ],
    );
  }
}

class _SourceChooser extends StatelessWidget {
  const _SourceChooser({required this.hasSaved});

  final bool hasSaved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSaved) ...[
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop('saved'),
            icon: const Icon(Icons.people_outline_rounded),
            label: const Text('Choose someone already saved'),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop('contacts'),
          icon: const Icon(Icons.contacts_rounded),
          label: const Text('Pick from contacts'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop('manual'),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Enter details manually'),
        ),
      ],
    );
  }
}

class _SavedPicker extends StatelessWidget {
  const _SavedPicker({required this.persons});

  final List<Person> persons;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final list = [...persons]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in list) ...[
          MonovaCard(
            padding: const EdgeInsets.all(12),
            onTap: () => Navigator.of(context).pop(p),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, color: c.accentStart),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${p.role} · ${p.phone}', style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Adds a person from the saved people, the phone's contacts, or typed details.
/// Returns the person (new or saved), or null if the owner backed out.
Future<Person?> addPersonFlow(BuildContext context, PropertyBook book, String propertyId, {String role = 'Tenant'}) async {
  final saved = [for (final p in book.persons) if (!p.isOwner) p];
  final choice = await FormSheet.show<String>(
    context,
    title: 'Add a person',
    child: _SourceChooser(hasSaved: saved.isNotEmpty),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == 'saved') {
    return FormSheet.show<Person>(context, title: 'Saved people', child: _SavedPicker(persons: saved));
  }
  String name = '';
  String phone = '';
  if (choice == 'contacts') {
    final c = await pickOneContact(context);
    if (c == null || !context.mounted) return null;
    name = c.name;
    phone = c.phone;
  }
  if (!context.mounted) return null;
  return FormSheet.show<Person>(
    context,
    title: 'Person details',
    child: PersonForm(propertyId: propertyId, role: role, prefillName: name, prefillPhone: phone),
  );
}

/// A person's page: contact details, stay history, the owner's review, edit, and delete.
class PersonScreen extends StatefulWidget {
  const PersonScreen({super.key, required this.id});

  final String id;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  PropertyBook _book = const PropertyBook();
  bool _loaded = false;
  Object? _error;
  int _rating = 0;
  final _review = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await PropertyStore.load();
      if (!mounted) return;
      final p = b.personById(widget.id);
      setState(() {
        _book = b;
        _loaded = true;
        _rating = p?.rating ?? 0;
        _review.text = p?.review ?? '';
      });
    } catch (e) {
      debugPrint('Person load failed: $e');
      if (mounted) setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  Future<void> _apply(PropertyBook next) async {
    setState(() => _book = next);
    try {
      await PropertyStore.save(next);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The change could not be saved. Please try again.')));
    }
  }

  Future<void> _edit(Person p) async {
    final updated = await FormSheet.show<Person>(context, title: 'Edit details', child: PersonForm(initial: p));
    if (updated == null) return;
    await _apply(_book.copyWith(
      persons: [for (final x in _book.persons) x.id == p.id ? updated : x],
      tenancies: [for (final t in _book.tenancies) t.personId == p.id ? t.copyWith(name: updated.name, phone: updated.phone) : t],
    ));
  }

  Future<void> _saveReview(Person p) async {
    await _apply(_book.copyWith(
      persons: [for (final x in _book.persons) x.id == p.id ? x.copyWith(rating: _rating, review: _review.text.trim()) : x],
    ));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review saved')));
  }

  Future<void> _delete(Person p, {required bool erase}) async {
    final problem = personDeletionProblem(_book, p.id, DateTime.now());
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(erase ? 'Erase this guest\'s data?' : 'Delete this person?'),
        content: Text(
          '${p.name}\'s details and their stay history will be removed from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.monova.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(erase ? 'Erase' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _apply(deletePerson(_book, p.id));
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/property');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (!_loaded) return const Scaffold(body: LoadingBox());
    final p = _book.personById(widget.id);
    if (_error != null || p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Person')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: _error != null ? 'Could not open this person' : 'Person not found',
          message: 'The record may have been erased or deleted.',
        ),
      );
    }
    final property = _book.propertyById(p.propertyId);
    final stays = _book.staysOf(p.id);
    final today = dayOnly(DateTime.now());

    Widget info(String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 118, child: Text(label, style: TextStyle(color: c.muted, fontSize: 12))),
            Expanded(child: SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w600))),
            IconButton(
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.copy_rounded, size: 18, color: c.accentStart),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
              },
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(p)),
          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(p, erase: false)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          MonovaCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: c.accentStart,
                      child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase(), style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          Text(
                            '${p.role}${property == null ? '' : ' · ${property.name}'}',
                            style: TextStyle(color: c.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                info('Mobile', p.phone),
                info('Email', p.email),
                info('Address', p.address),
                info('Emergency contact', p.emergencyName),
                info('Emergency number', p.emergencyPhone),
                info('ID proof', p.idType.isEmpty ? '' : '${p.idType} ····${p.idLast4}'),
                info('Added on', dayLabel(p.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Review'),
          const SizedBox(height: 8),
          MonovaCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        tooltip: '$i star${i == 1 ? '' : 's'}',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_border_rounded, color: c.warning),
                        onPressed: () => setState(() => _rating = i),
                      ),
                  ],
                ),
                TextField(
                  controller: _review,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Your review of this person', alignLabelWithHint: true),
                ),
                const SizedBox(height: 10),
                FilledButton(onPressed: () => _saveReview(p), child: const Text('Save review')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('History'),
          const SizedBox(height: 8),
          if (stays.isEmpty)
            MonovaCard(child: Text('No stays recorded yet.', style: TextStyle(color: c.muted)))
          else
            for (final t in stays) ...[
              MonovaCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room ${_book.roomById(t.roomId)?.number ?? '?'}${t.wholeRoom ? '' : ', bed ${t.bed}'}'
                      ' · ${property?.name ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'In ${dayLabel(t.checkIn)}'
                      '${t.actualCheckout != null ? ' · out ${dayLabel(t.actualCheckout!)}' : t.checkIn.isAfter(today) ? ' · booked' : ' · staying'}',
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                    if (t.actualCheckout != null)
                      Text(
                        'Deposit ${money(t.depositCents / 100)} · refund ${money(t.refundCents / 100)}'
                        '${t.deductionReason.isEmpty ? '' : ' · ${t.deductionReason}'}',
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          if (property?.retainsGuestData == true) ...[
            const SizedBox(height: 16),
            MonovaCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hotel guest details are erased $guestRetentionDays days after checkout. You can erase them now.',
                    style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _delete(p, erase: true),
                    icon: Icon(Icons.delete_sweep_outlined, color: c.expense),
                    label: Text('Erase guest data now', style: TextStyle(color: c.expense)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

