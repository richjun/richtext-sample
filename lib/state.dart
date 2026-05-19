import 'package:flutter/widgets.dart';
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
  final FocusNode focusNode;
  final ScrollController scrollController;

  BoxModel({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.scale = 1.0,
    this.rotationDeg = 0.0,
    QuillController? controller,
    FocusNode? focusNode,
    ScrollController? scrollController,
  })  : controller = controller ?? QuillController.basic(),
        focusNode = focusNode ?? FocusNode(),
        scrollController = scrollController ?? ScrollController();
}

class AppState extends ChangeNotifier {
  final List<BoxModel> boxes = [];
  String? selectedBoxId;
  // Set to true during an explicit deselect so the FocusNode listener does
  // not re-select the box if Flutter restores focus automatically.
  bool _suppressFocusSelect = false;

  BoxModel? get selectedBox =>
      boxes.where((b) => b.id == selectedBoxId).firstOrNull;

  void addBox(BoxModel b) {
    boxes.add(b);
    b.controller.addListener(_emit);
    b.focusNode.addListener(() {
      if (_suppressFocusSelect) return;
      if (b.focusNode.hasFocus && selectedBoxId != b.id) {
        selectedBoxId = b.id;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void select(String? id) {
    if (selectedBoxId == id) return;
    final prev = boxes.where((b) => b.id == selectedBoxId).firstOrNull;
    if (prev != null) {
      _suppressFocusSelect = true;
      // Collapse selection first so the visible highlight goes away, then
      // drop focus so the textarea host detaches.
      prev.controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        ChangeSource.local,
      );
      prev.focusNode.unfocus(disposition: UnfocusDisposition.scope);
      // Release the guard after the current microtask + next frame, so any
      // synchronous-or-microtask focus restoration is ignored.
      Future.microtask(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _suppressFocusSelect = false;
        });
      });
    }
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
