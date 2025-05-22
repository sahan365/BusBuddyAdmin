class Admin {
  final String id;
  final String name;
  final String email;

  Admin({required this.id, required this.name, required this.email});


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }


  factory Admin.fromMap(Map<String, dynamic> map) {
    return Admin(
      id: map['id'],
      name: map['name'],
      email: map['email'],
    );
  }
}
