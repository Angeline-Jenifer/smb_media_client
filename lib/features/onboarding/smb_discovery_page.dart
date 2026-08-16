import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/server_info.dart';
import '../../services/local_storage_service.dart';
import '../../services/nsd_service.dart';
import '../../services/smb_service.dart';


class SmbDiscoveryPage extends StatefulWidget {
  const SmbDiscoveryPage({super.key});

  @override
  State<SmbDiscoveryPage> createState() => _SmbDiscoveryPageState();
}

class _SmbDiscoveryPageState extends State<SmbDiscoveryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  StreamSubscription? _serverSub;
  List<ServerInfo> _servers = [];
  bool _isConnecting = false;
  bool _showManualInput = false;
  final _ipController = TextEditingController();
  final _nameController = TextEditingController(text: 'My Server');

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startScan();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _serverSub?.cancel();
    NsdService.instance.stopScan();
    _ipController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _startScan() {
    _serverSub = NsdService.instance.serversStream.listen((servers) {
      if (mounted) setState(() => _servers = servers);
    });
    NsdService.instance.startScan();
  }

  Future<void> _connectToServer(ServerInfo server) async {
    setState(() => _isConnecting = true);
    final success = await SmbService.instance.connect(server);

    if (success) {
      await LocalStorageService.instance.saveSmbServer(server);

   
      final shares = await SmbService.instance.listShares();
      if (shares.isNotEmpty) {
        await LocalStorageService.instance.saveSmbShare(shares.first);
      }

      await LocalStorageService.instance.setOnboardingComplete(true);
      if (mounted) context.go('/');
    } else {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorSmbConnect)),
        );
      }
    }
  }

  Future<void> _connectManually() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    final server = ServerInfo(
      name: _nameController.text.trim().isEmpty ? ip : _nameController.text.trim(),
      host: ip,
    );
    await _connectToServer(server);
  }

  Future<void> _skipSmb() async {
    await LocalStorageService.instance.setOnboardingComplete(true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
         
          SizedBox(
            width: 80,
            height: 80,
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPurple
                            .withValues(alpha: 0.2 + 0.2 * _radarController.value),
                        blurRadius: 24 + 12 * _radarController.value,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.wifi_find, size: 40, color: Colors.white),
                );
              },
            ),
          ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.elasticOut),

          const SizedBox(height: 24),
          Text(
            AppStrings.onboardingTitle2,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 8),
          Text(
            AppStrings.onboardingSubtitle2,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 24),

          if (_isConnecting) ...[
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.electricBlue),
                    SizedBox(height: 16),
                    Text(AppStrings.connecting,
                        style: TextStyle(color: AppColors.darkTextSecondary)),
                  ],
                ),
              ),
            ),
          ] else if (_showManualInput) ...[
         
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Server Name',
                labelStyle: TextStyle(color: AppColors.darkTextSecondary),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Server IP Address',
                hintText: '192.168.1.100',
                labelStyle: TextStyle(color: AppColors.darkTextSecondary),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _connectManually,
                child: const Text(AppStrings.connectToServer),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showManualInput = false),
              child: const Text('Back to discovery'),
            ),
            const Spacer(),
          ] else ...[
           
            if (_servers.isEmpty)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.scanning,
                      style: TextStyle(color: AppColors.darkTextSecondary),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.electricBlue,
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _servers.length,
                  itemBuilder: (context, index) {
                    final server = _servers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.neonPurple.withValues(alpha: 0.15),
                          ),
                          child: const Icon(Icons.dns, color: AppColors.neonPurple),
                        ),
                        title: Text(server.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(server.host,
                            style: TextStyle(color: AppColors.darkTextSecondary)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _connectToServer(server),
                      ),
                    ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.2, end: 0);
                  },
                ),
              ),

            TextButton.icon(
              onPressed: () => setState(() => _showManualInput = true),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text(AppStrings.enterManually),
            ),
          ],

         
          TextButton(
            onPressed: _skipSmb,
            child: Text(
              AppStrings.skipForNow,
              style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
