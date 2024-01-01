import 'dart:async';

Future<void> eachLimit<T>(
  Iterable<T> collection,
  int concurrency,
  Future<void> Function(T) iteratee,
) async {
  final streamController = StreamController<T>();
  final streamIterator = StreamIterator<T>(streamController.stream);

  for (final item in collection) {
    streamController.add(item);
  }
  streamController.close();

  final activeTasks = <Future<void>>[];
  while (await streamIterator.moveNext()) {
    final currentItem = streamIterator.current;
    final task = iteratee(currentItem);
    task.whenComplete(() {
      activeTasks.remove(task);
    }).onError((error, stackTrace) {
      print('error on item $currentItem');
      throw error!;
    });
    activeTasks.add(task);

    if (activeTasks.length >= concurrency) {
      await Future.any(activeTasks);
    }
  }

  await Future.wait(activeTasks);
}
