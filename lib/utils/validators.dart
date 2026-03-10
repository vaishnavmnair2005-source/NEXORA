class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@gmail\.com$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid Gmail address';
    }
    return null;
  }

 static String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }

  if (value.length < 6) {
    return 'Password must be at least 6 characters';
  }

  final passwordRegExp = RegExp(r'^[a-zA-Z0-9]+$');

  if (!passwordRegExp.hasMatch(value)) {
    return 'Password must contain only letters and numbers';
  }

  final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
  final hasNumber = RegExp(r'[0-9]').hasMatch(value);

  if (!hasLetter || !hasNumber) {
    return 'Password must contain both letters and numbers';
  }

  return null;
}


  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Contact number is required';
    }
    if (value.length != 10) {
      return 'Contact number must be 10 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Contact number must contain only numbers';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateDeviceNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Device number is required';
    }
    if (value.length < 6) {
      return 'Device number must be at least 6 characters';
    }
    return null;
  }

  static String? validateDeviceId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Device ID is required';
    }
    final mtFormat = RegExp(r'^MT-\d{4}$');
    if (!mtFormat.hasMatch(value.toUpperCase())) {
      return 'Format must be MT-0001 (found on device back)';
    }
    return null;
  }

  static String? validateTextArea(String? value, String fieldName, int maxWords) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final wordCount = value.trim().split(RegExp(r'\s+')).length;
    if (wordCount > maxWords) {
      return '$fieldName must not exceed $maxWords words';
    }
    return null;
  }
}