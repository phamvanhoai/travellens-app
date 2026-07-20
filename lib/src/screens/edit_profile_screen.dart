import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';
import '../features/auth/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _birthday = TextEditingController();
  final _address = TextEditingController();
  final _bio = TextEditingController();
  String _gender = '';
  String _avatar = '';
  XFile? _avatarFile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _birthday.dispose();
    _address.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(dioProvider).get('/auth/profile');
      dynamic data = unwrap(response.data);
      if (data is Map && data['user'] is Map) data = data['user'];
      final profile = Map<String, dynamic>.from(data as Map);
      _name.text = '${profile['name'] ?? ''}';
      _email.text = '${profile['email'] ?? ''}';
      _phone.text = '${profile['phone'] ?? ''}';
      _birthday.text = _dateOnly(profile['date_of_birth']);
      _address.text = '${profile['address'] ?? ''}';
      _bio.text = '${profile['profile_info'] ?? ''}';
      if (mounted) {
        setState(() {
          _gender = '${profile['gender'] ?? ''}';
          _avatar = '${profile['avatar_url'] ?? ''}';
          _avatarFile = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (file != null && mounted) setState(() => _avatarFile = file);
  }

  Future<void> _pickBirthday() async {
    final initial = DateTime.tryParse(_birthday.text) ?? DateTime(2000, 1, 1);
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (value != null) _birthday.text = DateFormat('yyyy-MM-dd').format(value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final values = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (_birthday.text.trim().isNotEmpty)
          'date_of_birth': _birthday.text.trim(),
        'gender': _gender,
        'address': _address.text.trim(),
        'profile_info': _bio.text.trim(),
      };
      if (_avatarFile != null) {
        values['avatar_file'] = await MultipartFile.fromFile(
          _avatarFile!.path,
          filename: _avatarFile!.name,
        );
      }
      await ref
          .read(dioProvider)
          .put('/auth/profile', data: FormData.fromMap(values));
      await ref.read(authProvider.notifier).restore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công.')),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: const Text('Edit Profile'),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _loading || _saving ? null : _load,
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: _loading
        ? const _ProfileSkeleton()
        : _error != null && _name.text.isEmpty
        ? AppErrorState(error: _error!, onRetry: _load)
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                const Text(
                  'Hồ sơ cá nhân',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Cập nhật thông tin và ảnh đại diện của bạn.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                _AvatarCard(
                  name: _name.text,
                  avatar: _avatar,
                  file: _avatarFile,
                  onPick: _saving ? null : _pickAvatar,
                  onClear: _avatarFile == null
                      ? null
                      : () => setState(() => _avatarFile = null),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _Label('Họ và tên'),
                const SizedBox(height: 6),
                _Field(
                  controller: _name,
                  hint: 'Nguyễn Văn A',
                  icon: Icons.person_outline_rounded,
                  validator: (value) =>
                      (value?.trim().split(RegExp(r'\s+')).length ?? 0) < 2
                      ? 'Vui lòng nhập đầy đủ họ tên.'
                      : null,
                ),
                const SizedBox(height: 13),
                _Label('Email'),
                const SizedBox(height: 6),
                _Field(
                  controller: _email,
                  hint: '',
                  icon: Icons.mail_outline_rounded,
                  enabled: false,
                ),
                const SizedBox(height: 13),
                _Label('Số điện thoại'),
                const SizedBox(height: 6),
                _Field(
                  controller: _phone,
                  hint: '0901234567',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      value != null &&
                          value.trim().isNotEmpty &&
                          !RegExp(
                            r'^0(?:3|5|7|8|9)\d{8}$',
                          ).hasMatch(value.trim())
                      ? 'Số điện thoại không hợp lệ.'
                      : null,
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('Ngày sinh'),
                          const SizedBox(height: 6),
                          _Field(
                            controller: _birthday,
                            hint: 'YYYY-MM-DD',
                            icon: Icons.calendar_month_outlined,
                            readOnly: true,
                            onTap: _pickBirthday,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('Giới tính'),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 46,
                            child: DropdownButtonFormField<String>(
                              initialValue: _gender.isEmpty ? null : _gender,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 11,
                                ),
                              ),
                              hint: const Text(
                                'Chọn',
                                style: TextStyle(fontSize: 12),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'male',
                                  child: Text('Nam'),
                                ),
                                DropdownMenuItem(
                                  value: 'female',
                                  child: Text('Nữ'),
                                ),
                                DropdownMenuItem(
                                  value: 'other',
                                  child: Text('Khác'),
                                ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (value) =>
                                        setState(() => _gender = value ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                _Label('Địa chỉ'),
                const SizedBox(height: 6),
                _Field(
                  controller: _address,
                  hint: 'Địa chỉ của bạn',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 13),
                _Label('Giới thiệu'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bio,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    hintText: 'Chia sẻ đôi nét về bạn...',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 17),
                    label: const Text('Cập nhật hồ sơ'),
                  ),
                ),
              ],
            ),
          ),
  );
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.name,
    required this.avatar,
    required this.file,
    required this.onPick,
    required this.onClear,
  });
  final String name, avatar;
  final XFile? file;
  final VoidCallback? onPick, onClear;
  @override
  Widget build(BuildContext context) {
    final url = AppConfig.assetUrl(avatar);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 64,
              height: 64,
              child: file != null
                  ? Image.file(File(file!.path), fit: BoxFit.cover)
                  : url.isNotEmpty
                  ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                  : ColoredBox(
                      color: AppColors.accentLight,
                      child: Center(
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ảnh đại diện',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                const Text(
                  'JPG, PNG hoặc WEBP',
                  style: TextStyle(fontSize: 9.5, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      height: 30,
                      child: FilledButton.tonalIcon(
                        onPressed: onPick,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                        ),
                        icon: const Icon(Icons.upload_rounded, size: 14),
                        label: const Text(
                          'Chọn ảnh',
                          style: TextStyle(fontSize: 9.5),
                        ),
                      ),
                    ),
                    if (onClear != null) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        onPressed: onClear,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(30, 30),
                          maximumSize: const Size(30, 30),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 15),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.keyboardType,
    this.validator,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool enabled, readOnly;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 46),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 12.5),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: const [
      AppShimmerBox(width: 150, height: 20, borderRadius: 6),
      SizedBox(height: 14),
      AppShimmerBox(width: double.infinity, height: 92, borderRadius: 14),
      SizedBox(height: 18),
      AppShimmerBox(width: double.infinity, height: 46, borderRadius: 10),
      SizedBox(height: 13),
      AppShimmerBox(width: double.infinity, height: 46, borderRadius: 10),
      SizedBox(height: 13),
      AppShimmerBox(width: double.infinity, height: 46, borderRadius: 10),
      SizedBox(height: 13),
      AppShimmerBox(width: double.infinity, height: 46, borderRadius: 10),
      SizedBox(height: 13),
      AppShimmerBox(width: double.infinity, height: 100, borderRadius: 10),
    ],
  );
}

String _dateOnly(dynamic value) {
  if (value == null || '$value'.isEmpty) return '';
  final date = DateTime.tryParse('$value');
  return date == null
      ? '$value'.split('T').first
      : DateFormat('yyyy-MM-dd').format(date);
}
