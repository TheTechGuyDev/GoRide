/// Nigerian phone helpers.
class PhoneUtils {
  PhoneUtils._();

  static const dialCode = '+234';

  /// Strips spaces and a leading 0. Returns the 10-digit national number.
  static String normalize(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('234')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return digits;
  }

  /// Valid Nigerian mobile: 10 digits starting with 7, 8 or 9.
  static bool isValid(String input) {
    final n = normalize(input);
    return RegExp(r'^[789][01]\d{8}$').hasMatch(n);
  }

  static String toE164(String input) => '$dialCode${normalize(input)}';

  /// +2348012345678 -> +234 801 234 5678
  static String pretty(String e164) {
    final n = e164.startsWith(dialCode) ? e164.substring(4) : e164;
    if (n.length != 10) return e164;
    return '$dialCode ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
  }
}
