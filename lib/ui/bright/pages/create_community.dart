import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:ace_toast/ace_toast.dart';
import 'package:oratio_app/bloc/auth_bloc/cubit/pocket_base_service_cubit.dart';
import 'package:oratio_app/bloc/community.dart';
import 'package:oratio_app/helpers/snackbars.dart';
import 'package:oratio_app/networkProvider/priest_requests.dart';
import 'package:oratio_app/networkProvider/users.dart';
import 'package:oratio_app/ui/themes.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class PrayerCommunityCreationPage extends StatefulWidget {
  const PrayerCommunityCreationPage({super.key, this.community});

  ///use id of an exisiting community to edit an exisiting community instead of creating a new one
  final PrayerCommunity? community;
  @override
  _PrayerCommunityCreationPageState createState() =>
      _PrayerCommunityCreationPageState();
}

class _PrayerCommunityCreationPageState
    extends State<PrayerCommunityCreationPage> {
  final FocusNode _leaderSearchFocusNode = FocusNode();
  final FocusNode _communityNameFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  final TextEditingController _communityNameController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _leaderSearchController = TextEditingController();

  String? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  List<RecordModel> _filteredLeaders = [];
  RecordModel? _selectedLeader;
  bool _showLeaderSearch = true;
  RecordModel? community;
  bool _isClosed = false;

  void getCommunity() async {}

  @override
  void initState() {
    super.initState();

    if (widget.community != null) {
      _selectedLeader = widget.community!.leader;
      _selectedImage = widget.community!.image;
      _communityNameController.text = widget.community!.community;
      _descriptionController.text = widget.community!.description;
    }
    _filteredLeaders = [];
    _leaderSearchController.addListener(_onLeaderSearchChange);
  }

  void _onLeaderSearchChange() {
    _filterLeaders(_leaderSearchController.text);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      final pb = getPocketBaseFromContext(context);

      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile.path;
        });
      }

      if (widget.community != null) {
        final bytes = await File(_selectedImage!).readAsBytes();
        final mimeType = lookupMimeType(_selectedImage!);
        if (mimeType != 'image/jpeg' && mimeType != 'image/png') {
          throw Exception('Invalid image type. Only JPEG and PNG are allowed.');
        }
        await pb
            .collection('prayer_community')
            .update(widget.community!.id, files: [
          http.MultipartFile.fromBytes(
            'image',
            bytes as List<int>,
            filename: pickedFile!.path,
            contentType: MediaType.parse(mimeType!),
          )
        ]);
        NotificationService.showInfo('Updated Community Image');
      }
    } catch (e) {
      showError(context, message: 'Error picking image: $e');
      print(e);
    }
  }

  Future<void> _filterLeaders(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredLeaders = [];
      });
      return;
    }
    final pb = context.read<PocketBaseServiceCubit>().state.pb;
    final potentialLeaders = await pb.collection("users").getList(
        perPage: 8,
        filter:
            'username ~ "$query" || first_name ~ "$query" || last_name ~ "$query" ');

    setState(() {
      _filteredLeaders = potentialLeaders.items;
    });
  }

  bool _validateInputs() {
    if (_communityNameController.text.trim().isEmpty) {
      showError(context, message: 'Please enter a community name');
      return false;
    }

    if (_descriptionController.text.trim().isEmpty) {
      showError(context, message: 'Please provide a community description');
      return false;
    }

    if (_selectedImage == null) {
      showError(context, message: 'Please select a community image');
      return false;
    }

    if (_selectedLeader == null) {
      showError(context, message: 'Please select a community leader');
      return false;
    }

    return true;
  }

  void _createCommunity() async {
    if (_validateInputs()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final pb = context.read<PocketBaseServiceCubit>().state.pb;
        final data = _collectFormData();
        print('Community Data: $data');
        final bytes = await File(_selectedImage!).readAsBytes();
        await pb.collection('prayer_community').create(body: data, files: [
          http.MultipartFile.fromBytes(
            'image',
            bytes as List<int>,
            filename: _selectedImage,
          )
        ]);
        NotificationService.showInfo('Created Community Succesfully');
        _clearForm();
        context.pop();
      } catch (e) {
        showError(context, message: 'Failed to create community: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void updateCommunity() async {
    if (_validateInputs()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final pb = context.read<PocketBaseServiceCubit>().state.pb;
        final data = _collectFormData();
        await pb
            .collection('prayer_community')
            .update(widget.community!.id, body: data);
        NotificationService.showSuccess('Updated Community Succesfully');
        _clearForm();
        context.pop();
      } catch (e) {
        NotificationService.showError('Error Updating details: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _collectFormData() {
    return {
      'community': _communityNameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'leader': _selectedLeader?.id,
      'isClosed': _isClosed
      // 'leaderChurch': _selectedLeader?['church'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.read<PocketBaseServiceCubit>().state.pb;
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            foregroundColor: Colors.white,
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.community != null
                    ? 'Update Community'
                    : 'Create Your Community',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                ),
                child: Center(
                  child: Icon(
                    Icons.people_outline,
                    color: AppColors.textDim,
                    size: 100,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Image Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: _selectedImage != null
                          ? null
                          : AppColors.inputBoxGray,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _selectedImage != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: (widget.community != null &&
                                        _selectedImage !=
                                            widget.community!.image)
                                    ? Image.file(
                                        File(_selectedImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : (widget.community != null)
                                        ? Image.network(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(_selectedImage!),
                                            fit: BoxFit.cover,
                                          ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Change Image',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
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
                              Icon(
                                Icons.camera_alt_outlined,
                                color: AppColors.primary,
                                size: 60,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Tap to add community photo',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_showLeaderSearch) ...[
                  _buildCustomInput(
                    controller: _leaderSearchController,
                    focusNode: _leaderSearchFocusNode,
                    hint: widget.community != null
                        ? widget.community!.leader.getStringValue('username')
                        : 'Find a Community Leader',
                    icon: Icons.search,
                    onChanged: _filterLeaders,
                  ),
                  if (_leaderSearchController.text.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredLeaders.length,
                        itemBuilder: (context, index) {
                          final leader = _filteredLeaders[index];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  leader.getStringValue("avatar").isNotEmpty
                                      ? CachedNetworkImageProvider(pb
                                          .getFileUrl(leader,
                                              leader.getStringValue("avatar"))
                                          .toString())
                                      : null,
                              child: leader.getStringValue("avatar").isNotEmpty
                                  ? null
                                  : const Icon(FontAwesomeIcons.user),
                            ),
                            title: Text(leader.getStringValue("username")),
                            // TODO DISPLAY CHURCH
                            subtitle: Text(getFullName(leader)),
                            onTap: () {
                              setState(() {
                                _selectedLeader = leader;
                                _showLeaderSearch = false;
                                _leaderSearchController.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                ] else if (_selectedLeader != null)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage:
                              _selectedLeader?.getStringValue('avatar') != null
                                  ? CachedNetworkImageProvider(pb
                                      .getFileUrl(
                                          _selectedLeader!,
                                          _selectedLeader!
                                              .getStringValue('avatar'))
                                      .toString())
                                  : null,
                          radius: 25,
                          child: _selectedLeader!
                                  .getStringValue("avatar")
                                  .isNotEmpty
                              ? null
                              : const Icon(FontAwesomeIcons.user),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedLeader!.getStringValue('username'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              // Text(
                              //   _selectedLeader!['church']!,
                              //   style: TextStyle(
                              //     color: AppColors.textDarkDim,
                              //     fontSize: 14,
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _selectedLeader = null;
                              _showLeaderSearch = true;
                            });
                          },
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 30),

                // Community Name Input
                _buildCustomInput(
                  controller: _communityNameController,
                  focusNode: _communityNameFocusNode,
                  hint: 'Community Name',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 20),

                // Description Input
                _buildCustomInput(
                  controller: _descriptionController,
                  focusNode: _descriptionFocusNode,
                  hint: 'Describe your community',
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                // isClosed Toggle
                Row(
                  children: [
                    Switch(
                      value: _isClosed,
                      onChanged: (val) {
                        setState(() {
                          _isClosed = val;
                        });
                      },
                      thumbColor: MaterialStatePropertyAll(AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isClosed
                            ? 'Community is closed (only admins can post)'
                            : 'Community is open (members can post)',
                        style: TextStyle(
                          color: AppColors.textDarkDim,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Leader Selection

                // Create Community Button
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : widget.community != null
                          ? updateCommunity
                          : _createCommunity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          widget.community != null
                              ? 'Update Community'
                              : 'Start Your Community',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBoxGray,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textDarkDim),
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _leaderSearchFocusNode.dispose();
    _communityNameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _communityNameController.dispose();
    _descriptionController.dispose();
    _leaderSearchController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _communityNameController.clear();
    _descriptionController.clear();
    _leaderSearchController.clear();
    _selectedImage = null;
    _selectedLeader = null;
    setState(() {});
  }
}
