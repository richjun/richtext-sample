import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';

class BoxModel {
  final String id;
  double x;
  double y;
  double width;
  double height;
  double scale;
  double rotationDeg;
  final QuillController controller;

  BoxModel({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.scale = 1.0,
    this.rotationDeg = 0.0,
    QuillController? controller,
  }) : controller = controller ?? QuillController.basic();
}

class AppState extends ChangeNotifier {
  final List<BoxModel> boxes = [];
  String? selectedBoxId;

  BoxModel? get selectedBox =>
      boxes.where((b) => b.id == selectedBoxId).firstOrNull;

  void addBox(BoxModel b) {
    boxes.add(b);
    b.controller.addListener(_emit);
    b.controller.changes.listen((_) => _emit());
    notifyListeners();
  }

  void select(String? id) {
    if (selectedBoxId == id) return;
    selectedBoxId = id;
    notifyListeners();
  }

  void mutateBox(String id, void Function(BoxModel) fn) {
    final b = boxes.firstWhere((b) => b.id == id);
    fn(b);
    notifyListeners();
  }

  void _emit() => notifyListeners();
}
