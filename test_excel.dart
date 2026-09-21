import 'package:excel/excel.dart';
void main() {
  final v = TextCellValue('hello');
  print(v.value.runtimeType);
  print(v.value.toString());
}
