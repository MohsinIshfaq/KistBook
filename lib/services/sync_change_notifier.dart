import 'dart:async';

enum SyncResource { customers, products, installmentPlans }

class SyncChangeNotifier {
  final StreamController<SyncResource> _controller =
      StreamController<SyncResource>.broadcast();

  Stream<SyncResource> get stream => _controller.stream;

  void notify(SyncResource resource) {
    if (!_controller.isClosed) {
      _controller.add(resource);
    }
  }

  void dispose() {
    _controller.close();
  }
}
