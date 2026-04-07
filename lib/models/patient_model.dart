class Patient {
  final String id;
  
  // Signup Info
  final String gmail;
  final String deviceNumber;
  final String deviceId;
  final String password;
  
  // Personal Info
  final String? firstName;
  final String? lastName;
  final String? contactNumber;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? residentialAddress;
  
  // Medical Info
  final String? hospital;
  final String? doctor;
  final String? bloodGroup;
  final String? allergies;
  final String? medicalHistory;
  final String? currentStatus;
  
  // Caregiver Info (optional)
  final String? caregiverName;
  final String? caregiverContact;

  Patient({
    required this.id,
    required this.gmail,
    required this.deviceNumber,
    required this.deviceId,
    required this.password,
    this.firstName,
    this.lastName,
    this.contactNumber,
    this.dateOfBirth,
    this.gender,
    this.residentialAddress,
    this.hospital,
    this.doctor,
    this.bloodGroup,
    this.allergies,
    this.medicalHistory,
    this.currentStatus,
    this.caregiverName,
    this.caregiverContact,
  });

  Patient copyWith({
    String? firstName,
    String? lastName,
    String? contactNumber,
    DateTime? dateOfBirth,
    String? gender,
    String? residentialAddress,
    String? hospital,
    String? doctor,
    String? bloodGroup,
    String? allergies,
    String? medicalHistory,
    String? currentStatus,
    String? caregiverName,
    String? caregiverContact,
  }) {
    return Patient(
      id: this.id,
      gmail: this.gmail,
      deviceNumber: this.deviceNumber,
      deviceId: this.deviceId,
      password: this.password,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      contactNumber: contactNumber ?? this.contactNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      hospital: hospital ?? this.hospital,
      doctor: doctor ?? this.doctor,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      currentStatus: currentStatus ?? this.currentStatus,
      caregiverName: caregiverName ?? this.caregiverName,
      caregiverContact: caregiverContact ?? this.caregiverContact,
    );
  }

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
}