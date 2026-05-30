String formatBRL(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  var intPart = parts[0];
  final decPart = parts[1];
  final buffer = StringBuffer();
  int count = 0;
  for (int i = intPart.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buffer.write('.');
    buffer.write(intPart[i]);
    count++;
  }
  return '${buffer.toString().split('').reversed.join()},$decPart';
}
