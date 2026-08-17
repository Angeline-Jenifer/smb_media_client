import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/google_drive_service.dart';
import '../../services/local_storage_service.dart';

class GoogleDriveSetupPage extends StatefulWidget {
  final VoidCallback onNext;

  const GoogleDriveSetupPage({super.key, required this.onNext});

  @override
  State<GoogleDriveSetupPage> createState() => _GoogleDriveSetupPageState();
}

class _GoogleDriveSetupPageState extends State<GoogleDriveSetupPage> {
  bool _isSigningIn = false;
  bool _isSignedIn = false;
  bool _isLoadingFolders = false;
  List<drive.File> _folders = [];
  String? _selectedFolderId;
  String? _selectedFolderName;

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    final success = await GoogleDriveService.instance.signIn();
    if (success) {
      setState(() {
        _isSignedIn = true;
        _isSigningIn = false;
      });
      _loadFolders();
    } else {
      setState(() => _isSigningIn = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorDriveAuth)),
        );
      }
    }
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoadingFolders = true);
    try {
      final folders = await GoogleDriveService.instance.listFolders();
      setState(() {
        _folders = folders;
        _isLoadingFolders = false;
      });
    } catch (e) {
      setState(() => _isLoadingFolders = false);
    }
  }

  Future<void> _selectFolder(drive.File folder) async {
    setState(() {
      _selectedFolderId = folder.id;
      _selectedFolderName = folder.name;
    });
  }

  Future<void> _confirmAndProceed() async {
    if (_selectedFolderId != null && _selectedFolderName != null) {
      await LocalStorageService.instance
          .saveDriveFolder(_selectedFolderId!, _selectedFolderName!);
      await LocalStorageService.instance.setDefaultMode('outdoor');
    }
    widget.onNext();
  }

  void _skip() {
    LocalStorageService.instance.setDefaultMode('indoor');
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
       
          // Simple Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkSurfaceVariant,
            ),
            child: const Icon(Icons.cloud_outlined, size: 40, color: AppColors.electricBlue),
          ),

          const SizedBox(height: 32),
          Text(
            AppStrings.onboardingTitle1,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
          ),

          const SizedBox(height: 12),
          Text(
            AppStrings.onboardingSubtitle1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
          ),

          const SizedBox(height: 48),

          if (!_isSignedIn) ...[
            // Simple Login Container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.lock_outline, size: 32, color: AppColors.darkTextSecondary),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSigningIn ? null : _signIn,
                      icon: _isSigningIn
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.login),
                      label: Text(_isSigningIn ? 'Authenticating...' : AppStrings.connectGoogleDrive),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              AppStrings.selectMusicFolder,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingFolders
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _folders.isEmpty
                      ? Center(
                          child: Text(
                            'No folders found',
                            style: TextStyle(color: AppColors.darkTextSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _folders.length,
                          itemBuilder: (context, index) {
                            final folder = _folders[index];
                            final isSelected = _selectedFolderId == folder.id;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  Icons.folder,
                                  color: isSelected
                                      ? AppColors.electricBlue
                                      : AppColors.darkTextSecondary,
                                ),
                                title: Text(
                                  folder.name ?? 'Untitled',
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.electricBlue
                                        : AppColors.darkTextPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppColors.electricBlue)
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                tileColor: isSelected
                                    ? AppColors.electricBlue.withValues(alpha: 0.1)
                                    : null,
                                onTap: () => _selectFolder(folder),
                              ),
                            );
                          },
                        ),
            ),
            if (_selectedFolderId != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmAndProceed,
                  child: const Text('Continue'),
                ),
              ),
            const SizedBox(height: 16),
          ],

          const Spacer(),
       
          TextButton(
            onPressed: _skip,
            child: Text(
              AppStrings.skipForNow,
              style: TextStyle(
                color: AppColors.darkTextTertiary,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
