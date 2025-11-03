import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:ace_toast/ace_toast.dart';
import 'package:oratio_app/bloc/auth_bloc/cubit/pocket_base_service_cubit.dart';
import 'package:oratio_app/bloc/posts/post_state.dart';
import 'package:oratio_app/bloc/profile_cubit/profile_data_cubit.dart';
import 'package:oratio_app/helpers/snackbars.dart';
import 'package:oratio_app/networkProvider/priest_requests.dart';
import 'package:oratio_app/ui/routes/route_names.dart';
import 'package:oratio_app/ui/themes.dart';
import 'package:pocketbase/pocketbase.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key, this.postToEdit});
  final Post? postToEdit;
  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCommunity;
  String? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Map<String, dynamic> _collectFormData() {
    return {
      'community': _selectedCommunity,
      'post': _descriptionController.text.trim(),
    };
  }

  Future<List<RecordModel>> getUserCommunities() async {
    final pb = getPocketBaseFromContext(context);
    final communities = await pb.collection('prayer_community').getList(
        filter: 'isClosed = false && members ~ "${pb.authStore.model.id}" ');
    return communities.items;
  }

  List<RecordModel> getInitialData() {
    try {
      final profileCubit = context.read<ProfileDataCubit>();
      return (profileCubit.state as ProfileDataLoaded)
          .profile
          .community
          .where((item) =>
              item.getStringValue('leader') ==
              (profileCubit.state as ProfileDataLoaded).profile.userId)
          .toList();
    } catch (e) {}
    return [];
  }

  void updatePost() async {
    if (_validateAndSubmit()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final pb = getPocketBaseFromContext(context);
        await pb
            .collection('posts')
            .update(widget.postToEdit!.id, body: _collectFormData());
        NotificationService.showSuccess('Updated Post!');
        context.pop();
      } catch (e) {
        NotificationService.showError('Failed to update post');
        context.pop();
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void createPost() async {
    if (_validateAndSubmit()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final pb = context.read<PocketBaseServiceCubit>().state.pb;
        final data = _collectFormData();
        if (_selectedImage != null) {
          final bytes = await File(_selectedImage!).readAsBytes();
          final mimeType = lookupMimeType(_selectedImage!);
          if (mimeType != 'image/jpeg' && mimeType != 'image/png') {
            throw Exception(
                'Invalid image type. Only JPEG and PNG are allowed.');
          }
          await pb.collection('posts').create(body: data, files: [
            http.MultipartFile.fromBytes(
              'image',
              bytes as List<int>,
              filename: _selectedImage!,
              contentType: MediaType.parse(mimeType!),
            )
          ]);
        } else {
          await pb.collection('posts').create(body: data);
        }

        NotificationService.showInfo('Created New Post');

        _clearForm();
        context.goNamed(RouteNames.homePage);
      } catch (e) {
        showError(context, message: 'Failed to create Post: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    if (widget.postToEdit != null) {
      _descriptionController.text = widget.postToEdit!.post;
      _selectedCommunity = widget.postToEdit!.communityId;
      _selectedImage = widget.postToEdit!.image;
    }
    super.initState();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, requestFullMetadata: true);
    if (image != null) {
      final mimeType = lookupMimeType(image.path);
      if (mimeType == 'image/jpeg' || mimeType == 'image/png') {
        setState(() {
          _selectedImage = image.path;
        });
        final pb = getPocketBaseFromContext(context);
        final bytes = await File(_selectedImage!).readAsBytes();

        if (widget.postToEdit != null) {
          await pb.collection('posts').update(widget.postToEdit!.id, files: [
            http.MultipartFile.fromBytes(
              'avatar',
              bytes as List<int>,
              filename: _selectedImage!,
            )
          ]);
          NotificationService.showInfo('Updated post image');
        }
      } else {
        showError(context,
            message: 'Invalid image type. Only JPEG and PNG are allowed.');
      }
    }
  }

  bool _validateAndSubmit() {
    return _formKey.currentState?.validate() == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.postToEdit != null ? 'Edit Post' : 'Create New Post',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            color: Colors.black, // Changed to black
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Image Picker Section
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Image',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black, // Changed to black
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 200, // Increased height
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: _selectedImage != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: widget.postToEdit != null
                                          ? Image.network(
                                              fit: BoxFit.cover,
                                              widget.postToEdit!.image!,
                                            )
                                          : Image.file(
                                              File(_selectedImage!),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                            ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Change Image',
                                              style: TextStyle(
                                                color: Colors
                                                    .black87, // Changed to a shade of black
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.accent.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 40,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Tap to add your image',
                                      style: TextStyle(
                                        color: Colors
                                            .black54, // Changed to a shade of black
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Description Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Post',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black, // Changed to black
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText:
                                  'Share your thoughts with the community...',
                              hintStyle: const TextStyle(
                                color: Colors
                                    .black38, // Changed to a shade of black
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (value) => value?.isEmpty == true
                                ? 'Please enter a post'
                                : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Community Selection Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Community',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black, // Changed to black
                            ),
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<List<RecordModel>>(
                              future: getUserCommunities(),
                              initialData: getInitialData(),
                              builder: (context, snapshot) {
                                return DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  hint: const Text(
                                    'Choose your community',
                                    style: TextStyle(
                                      color: Colors
                                          .black38, // Changed to a shade of black
                                      fontSize: 14,
                                    ),
                                  ),
                                  value: _selectedCommunity,
                                  items: snapshot.data!
                                      .map((RecordModel community) {
                                    return DropdownMenuItem<String>(
                                      value: community.id,
                                      child: Text(community
                                          .getStringValue('community')),
                                    );
                                  }).toList(),
                                  validator: (value) => value == null
                                      ? 'Please select a community'
                                      : null,
                                  onChanged: (String? newValue) {
                                    setState(
                                        () => _selectedCommunity = newValue);
                                  },
                                );
                              }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.postToEdit != null
                              ? updatePost()
                              : createPost();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isLoading
                              ? 'Please wait..'
                              : widget.postToEdit != null
                                  ? 'Update Post'
                                  : 'Share Post',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _validateAndSubmit()
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _descriptionController.clear();
    _selectedCommunity = null;

    _selectedImage = null;
    setState(() {});
  }
}
