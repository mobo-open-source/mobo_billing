class UserModel {
  final int uid;
  final String username;
  final String name;
  final String serverUrl;
  final String database;
  final String? sessionId;
  final Map<String, dynamic> context;
  final String? profileImage;

  UserModel({
    required this.uid,
    required this.username,
    required this.name,
    required this.serverUrl,
    required this.database,
    this.sessionId,
    this.context = const {},
    this.profileImage,
  });

  /// Creates a UserModel from a JSON map.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? 0,
      username: json['username'] ?? '',
      name: json['name'] ?? json['username'] ?? '',
      serverUrl: json['serverUrl'] ?? '',
      database: json['database'] ?? '',
      sessionId: json['sessionId'],
      context: json['context'] ?? {},
      profileImage: json['profileImage'],
    );
  }

  /// Converts the user model to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'name': name,
      'serverUrl': serverUrl,
      'database': database,
      'sessionId': sessionId,
      'context': context,
      'profileImage': profileImage,
    };
  }

  UserModel copyWith({
    int? uid,
    String? username,
    String? name,
    String? serverUrl,
    String? database,
    String? sessionId,
    Map<String, dynamic>? context,
    String? profileImage,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      name: name ?? this.name,
      serverUrl: serverUrl ?? this.serverUrl,
      database: database ?? this.database,
      sessionId: sessionId ?? this.sessionId,
      context: context ?? this.context,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}
