import 'dart:async';
import 'package:flutter/material.dart';
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

class _SmbDiscoveryPageState extends State<SmbDiscoveryPage> {
  StreamSubscription? _serverSub;
  List<ServerInfo> _servers = [];
  bool _isConnecting = false;
  bool _showManualInput = false;
  final _ipController = TextEditingController();
  final _nameController = TextEditingController(text: 'My Server');

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
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
         
          // Simple Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkSurfaceVariant,
            ),
            child: const Icon(Icons.wifi_find, size: 40, color: AppColors.electricBlue),
          ),

          const SizedBox(height: 32),
          Text(
            AppStrings.onboardingTitle2,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
          ),

          const SizedBox(height: 12),
          Text(
            AppStrings.onboardingSubtitle2,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
          ),

          const SizedBox(height: 48),

          if (_isConnecting) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(AppStrings.connecting,
                        style: const TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ] else if (_showManualInput) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Server Name',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Server IP Address',
                      hintText: '192.168.1.100',
                      prefixIcon: Icon(Icons.router_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _connectManually,
                      child: const Text(AppStrings.connectToServer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                      style: const TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
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
                        leading: const Icon(Icons.dns),
                        title: Text(server.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(server.host,
                            style: const TextStyle(color: AppColors.darkTextSecondary)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _connectToServer(server),
                      ),
                    );
                  },
                ),
              ),

            TextButton.icon(
              onPressed: () => setState(() => _showManualInput = true),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text(AppStrings.enterManually),
            ),
          ],

          TextButton(
            onPressed: _skipSmb,
            child: const Text(
              AppStrings.skipForNow,
              style: TextStyle(color: AppColors.darkTextTertiary, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
