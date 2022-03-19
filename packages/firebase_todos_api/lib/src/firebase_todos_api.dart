import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/subjects.dart';
import 'package:todos_api/todos_api.dart';

/// {@template local_storage_todos_api}
/// A Flutter implementation of the [TodosApi] that uses local storage.
/// {@endtemplate}
class FirebaseTodosApi extends TodosApi {
  /// {@macro local_storage_todos_api}
  FirebaseTodosApi() {
    _init();
  }

  final FirebaseFirestore _plugin = FirebaseFirestore.instance;

  final _todoStreamController = BehaviorSubject<List<Todo>>.seeded(const []);

  /// The key used for storing the todos locally.
  ///
  /// This is only exposed for testing and shouldn't be used by consumers of
  /// this library.
  @visibleForTesting
  static const kTodosCollectionKey = 'todo';

  Future<List<Todo>>? _getValue(String key) async {
    final result = await _plugin.collection(kTodosCollectionKey).get();
    return result.docs.map((e) => Todo.fromJson(e.data())).toList();
  }

  Future<void> _setValue(String key, Todo value) async {
    await _plugin.collection(key).doc(value.id).set(value.toJson());
    }

  Future<void> _removeValue(String key, String id) async {
    await _plugin.collection(key).doc(id).delete();
  }

  Future<void> _init() async {
    final todosJson = _getValue(kTodosCollectionKey);
    if (todosJson != null) {
      final todos = await todosJson;
      _todoStreamController.add(todos);
    } else {
      _todoStreamController.add(const []);
    }
  }

  @override
  Stream<List<Todo>> getTodos() => _todoStreamController.asBroadcastStream();

  @override
  Future<void> saveTodo(Todo todo) {
    final todos = [..._todoStreamController.value];
    final todoIndex = todos.indexWhere((t) => t.id == todo.id);
    if (todoIndex >= 0) {
      todos[todoIndex] = todo;
    } else {
      todos.add(todo);
    }

    _todoStreamController.add(todos);
    return _setValue(kTodosCollectionKey, todo);
  }

  @override
  Future<void> deleteTodo(String id) async {
    final todos = [..._todoStreamController.value];
    final todoIndex = todos.indexWhere((t) => t.id == id);
    if (todoIndex == -1) {
      throw TodoNotFoundException();
    } else {
      todos.removeAt(todoIndex);
      _todoStreamController.add(todos);

      return _removeValue(kTodosCollectionKey, id);
    }
  }

  @override
  Future<int> clearCompleted() async {
    final todos = [..._todoStreamController.value];
    final completedTodosAmount = todos.where((t) => t.isCompleted).length;
    todos.removeWhere((t) {
      if (t.isCompleted) {
        _removeValue(kTodosCollectionKey, t.id);
      }
      return t.isCompleted;
    });
    _todoStreamController.add(todos);

    return completedTodosAmount;
  }

  @override
  Future<int> completeAll({required bool isCompleted}) async {
    final todos = [..._todoStreamController.value];
    final changedTodosAmount = todos.where((t) => t.isCompleted != isCompleted).length;
    final newTodos = todos.map((e) {
      final todo = e.copyWith(isCompleted: isCompleted);
      _setValue(kTodosCollectionKey, todo);
      return todo;
    }).toList();
    _todoStreamController.add(newTodos);

    return changedTodosAmount;
  }
}
