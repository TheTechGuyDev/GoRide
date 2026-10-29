/// ₦12,500
String naira(num amount) {
  final whole = amount.round();
  final digits = whole.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${whole < 0 ? '-' : ''}₦$buf';
}

/// Round fares to the nearest ₦50, like Nigerian cash change.
int roundFare(double amount) => ((amount / 50).round() * 50);
