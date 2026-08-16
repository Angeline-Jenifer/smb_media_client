class ServerInfo {
  final String name;
  final String host;
  final int port;
  final bool isAnonymous;

  const ServerInfo({
    required this.name,
    required this.host,
    this.port = 445,
    this.isAnonymous = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'host': host,
        'port': port,
        'isAnonymous': isAnonymous,
      };

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int? ?? 445,
        isAnonymous: json['isAnonymous'] as bool? ?? true,
      );

  @override
  String toString() => 'ServerInfo($name @ $host:$port)';
}
