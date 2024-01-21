import 'dart:async';

import 'package:rxdart/src/utils/collection_extensions.dart';
import 'package:rxdart/src/utils/subscription.dart';

class CombineAnyLatestStream<T, R> extends StreamView<R> {
  CombineAnyLatestStream(List<Stream<T>> streams, R Function(List<T?>) combiner)
      : super(_buildController(streams, combiner).stream);

  static StreamController<R> _buildController<T, R>(
    Iterable<Stream<T>> streams,
    R Function(List<T?> values) combiner,
  ) {
    int completed = 0;

    late List<StreamSubscription<T>> subscriptions;
    List<T?>? values;

    final _controller = StreamController<R>(sync: true);

    _controller.onListen = () {
      void onDone() {
        if (++completed == streams.length) {
          _controller.close();
        }
      }

      subscriptions = streams.mapIndexed((index, stream) {
        return stream.listen((T event) {
          final R combined;

          if (values == null) return;

          values![index] = event;

          try {
            combined = combiner(List<T?>.unmodifiable(values!));
          } catch (e, s) {
            _controller.addError(e, s);
            return;
          }

          _controller.add(combined);
        }, onError: _controller.addError, onDone: onDone);
      }).toList(growable: false);

      if (subscriptions.isEmpty) {
        _controller.close();
      } else {
        values = List<T?>.filled(subscriptions.length, null);
      }
    };

    _controller.onPause = () => subscriptions.pauseAll();
    _controller.onResume = () => subscriptions.resumeAll();
    _controller.onCancel = () {
      values = null;
      return subscriptions.cancelAll();
    };

    return _controller;
  }
}
