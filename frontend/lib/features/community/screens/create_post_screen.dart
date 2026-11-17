import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/l10n/app_localizations.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../models/post.dart';
import '../services/community_api_service.dart';
import '../widgets/community_labels.dart';

/// Create a post, or edit one when [existing] is given. Pops with the saved Post.
class CreatePostScreen extends StatefulWidget {
  final Post? existing;
  const CreatePostScreen({super.key, this.existing});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late PostCategory _category;
  File? _newImage;
  bool _removeExistingImage = false;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _body = TextEditingController(text: widget.existing?.body ?? '');
    _category = widget.existing?.category ?? PostCategory.general;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1920);
    if (picked == null) return;
    setState(() {
      _newImage = File(picked.path);
      _removeExistingImage = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final t = AppLocalizations.of(context);
    final api = context.read<CommunityApiService>();
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      var post = _editing
          ? await api.updatePost(widget.existing!.id,
              title: _title.text.trim(), body: _body.text.trim(), category: _category)
          : await api.createPost(title: _title.text.trim(), body: _body.text.trim(), category: _category);
      if (_newImage != null) {
        post = await api.uploadPostImage(post.id, _newImage!);
      } else if (_removeExistingImage && post.imageUrl != null) {
        post = await api.removePostImage(post.id);
      }
      navigator.pop(post);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(t, e.statusCode, e.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final existingImage = _removeExistingImage ? null : widget.existing?.imageUrl;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? t.requiredField : null;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? t.editPost : t.newPost)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: t.postTitle, border: const OutlineInputBorder()),
              validator: required,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PostCategory>(
              initialValue: _category,
              decoration: InputDecoration(labelText: t.postCategory, border: const OutlineInputBorder()),
              items: PostCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(postCategoryLabel(t, c))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              minLines: 5,
              maxLines: 12,
              maxLength: 10000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t.postBody,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              validator: required,
            ),
            const SizedBox(height: 12),
            if (_newImage != null)
              _ImagePreview(image: Image.file(_newImage!, fit: BoxFit.cover), onRemove: () => setState(() => _newImage = null))
            else if (existingImage != null)
              _ImagePreview(
                image: Image.network(existingImage, fit: BoxFit.cover),
                onRemove: () => setState(() => _removeExistingImage = true),
              ),
            if (_newImage == null && existingImage == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(t.addImage, style: Theme.of(context).textTheme.titleSmall),
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(t.chooseFromGallery),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(t.captureImage),
                ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _editing ? t.saveChanges : t.publish,
              icon: Icons.check,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final Widget image;
  final VoidCallback onRemove;
  const _ImagePreview({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(aspectRatio: 16 / 9, child: image),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filledTonal(
              tooltip: t.removeImage,
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}
