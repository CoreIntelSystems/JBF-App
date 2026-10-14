import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/ids.dart';
import '../../data/database.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/zone_rules.dart';
import '../auth/auth_cubit.dart';

const genders = ['Male', 'Female'];
const maritalStatuses = ['Single', 'Married', 'Divorced', 'Widowed'];

/// Registers a new member, or edits one when [existing] is given.
class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key, this.existing});

  final MemberWithZones? existing;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _form = GlobalKey<FormState>();
  late final MemberDraft _draft;
  late final Set<String> _originalZones;
  List<Zone> _zones = const [];
  bool _saving = false;

  late final _c = <String, TextEditingController>{
    'fullName': TextEditingController(text: _draft.fullName),
    'nationality': TextEditingController(text: _draft.nationality),
    'occupation': TextEditingController(text: _draft.occupation),
    'location': TextEditingController(text: _draft.location),
    'phone': TextEditingController(text: _draft.phone),
    'whatsapp': TextEditingController(text: _draft.whatsapp),
    'email': TextEditingController(text: _draft.email),
    'address': TextEditingController(text: _draft.address),
    'gpsAddress': TextEditingController(text: _draft.gpsAddress),
    'emergencyName': TextEditingController(text: _draft.emergencyName),
    'emergencyPhone': TextEditingController(text: _draft.emergencyPhone),
  };

  AppServices get _services => context.read<AppServices>();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _draft = e == null
        ? MemberDraft(
            fullName: '',
            nationality: 'Ghanaian',
            dateJoined: DateTime.now(),
            zoneIds: [],
          )
        : MemberDraft.fromMember(
            e.member,
            e.zones.map((z) => z.id).toList(),
            primaryZoneId: e.primaryZoneId,
          );
    _originalZones = _draft.zoneIds.toSet();
    _services.members.zones().then((z) {
      if (mounted) setState(() => _zones = z);
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleZone(Zone zone, bool selected) {
    setState(() {
      if (!selected) {
        _draft.zoneIds.remove(zone.id);
        if (_draft.primaryZoneId == zone.id) _draft.primaryZoneId = null;
        return;
      }
      if (!ZoneRules.canAddAnother(_draft.zoneIds)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                '${ZoneRules.tooManyMessage} Remove one zone first.',
              ),
            ),
          );
        return;
      }
      _draft.zoneIds.add(zone.id);
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
    );
    if (picked == null) return;
    final dir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'photos'),
    );
    await dir.create(recursive: true);
    final saved = await File(
      picked.path,
    ).copy(p.join(dir.path, '${newId()}.jpg'));
    setState(() => _draft.photoPath = saved.path);
  }

  Future<DateTime?> _pickDate(DateTime? initial, {DateTime? first}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(now.year - 30, 6, 1),
      firstDate: first ?? DateTime(1900),
      lastDate: now,
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final active = _zones.where((z) => z.isActive).map((z) => z.id).toSet();
    final zoneError = ZoneRules.validate(
      _draft.zoneIds,
      activeZoneIds: active,
      alreadyAssigned: _originalZones,
    );
    if (zoneError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(zoneError)));
      return;
    }
    String text(String k) => _c[k]!.text;
    _draft
      ..fullName = text('fullName')
      ..nationality = text('nationality')
      ..occupation = text('occupation')
      ..location = text('location')
      ..phone = text('phone')
      ..whatsapp = text('whatsapp')
      ..email = text('email')
      ..address = text('address')
      ..gpsAddress = text('gpsAddress')
      ..emergencyName = text('emergencyName')
      ..emergencyPhone = text('emergencyPhone');

    final user = context.read<AuthCubit>().user!;
    final actor = user.actor(_services.deviceId);
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        final m = await _services.members.create(_draft, actor);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${m.fullName} registered as ${m.memberNo}')),
        );
      } else {
        await _services.members.update(
          widget.existing!.member.id,
          _draft,
          actor,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ZoneRuleException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit member' : 'Register member')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (editing)
              Text(
                'Member ID: ${widget.existing!.member.memberNo}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            _photo(),
            _section('Personal information'),
            _field(
              'fullName',
              'Full name *',
              caps: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the full name.' : null,
            ),
            _choice('Gender', genders, _draft.gender, (v) => _draft.gender = v),
            _dateTile(
              'Date of birth',
              _draft.dateOfBirth,
              (d) => _draft.dateOfBirth = d,
              clearable: true,
            ),
            _field(
              'nationality',
              'Nationality',
              caps: TextCapitalization.words,
            ),
            _field(
              'occupation',
              'Occupation',
              caps: TextCapitalization.sentences,
            ),
            _choice(
              'Marital status',
              maritalStatuses,
              _draft.maritalStatus,
              (v) => _draft.maritalStatus = v,
            ),
            _field(
              'location',
              'Location (town / area)',
              caps: TextCapitalization.words,
            ),
            _section('Contact'),
            _field(
              'phone',
              'Mobile number *',
              keyboard: TextInputType.phone,
              validator: (v) => (v ?? '').trim().length < 9
                  ? 'Enter a valid phone number.'
                  : null,
            ),
            _field(
              'whatsapp',
              'WhatsApp number',
              keyboard: TextInputType.phone,
            ),
            _field(
              'email',
              'Email address',
              keyboard: TextInputType.emailAddress,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                    ? null
                    : 'Enter a valid email address.';
              },
            ),
            _field(
              'address',
              'Residential address',
              caps: TextCapitalization.sentences,
            ),
            _field(
              'gpsAddress',
              'GPS address (e.g. GA-123-4567)',
              caps: TextCapitalization.characters,
            ),
            _section('Emergency contact'),
            _field(
              'emergencyName',
              'Contact person',
              caps: TextCapitalization.words,
            ),
            _field(
              'emergencyPhone',
              'Contact number',
              keyboard: TextInputType.phone,
            ),
            _section('Membership'),
            _dateTile('Date joined *', _draft.dateJoined, (d) {
              if (d != null) _draft.dateJoined = d;
            }, first: DateTime(1990)),
            _zonePicker(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(editing ? 'Save changes' : 'Register member'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _field(
    String key,
    String label, {
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _c[key],
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboard,
        textCapitalization: caps,
        validator: validator,
      ),
    );
  }

  Widget _choice(
    String label,
    List<String> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: options.contains(value) ? value : null,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    );
  }

  Widget _dateTile(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged, {
    bool clearable = false,
    DateTime? first,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final d = await _pickDate(value, first: first);
          if (d != null) setState(() => onChanged(d));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: clearable && value != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => onChanged(null)),
                  )
                : const Icon(Icons.calendar_today),
          ),
          child: Text(value == null ? 'Tap to choose' : formatDate(value)),
        ),
      ),
    );
  }

  Widget _photo() {
    final path = _draft.photoPath;
    final hasPhoto = path != null && File(path).existsSync();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: hasPhoto ? FileImage(File(path)) : null,
            child: hasPhoto ? null : const Icon(Icons.person, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zonePicker() {
    final selected = _draft.zoneIds;
    final selectedZones = _zones.where((z) => selected.contains(z.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zones * (choose 1 or 2) · ${selected.length} of ${ZoneRules.maxZones}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final z in _zones)
              FilterChip(
                label: Text(
                  z.isActive
                      ? zoneDisplayName(z)
                      : '${zoneDisplayName(z)} (not open)',
                ),
                selected: selected.contains(z.id),
                onSelected: z.isActive || _originalZones.contains(z.id)
                    ? (v) => _toggleZone(z, v)
                    : null,
              ),
          ],
        ),
        if (selectedZones.length == 2) ...[
          const SizedBox(height: 12),
          Text('Primary zone', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final z in selectedZones)
                ChoiceChip(
                  label: Text(zoneDisplayName(z)),
                  selected: (_draft.primaryZoneId ?? selected.first) == z.id,
                  onSelected: (_) =>
                      setState(() => _draft.primaryZoneId = z.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
