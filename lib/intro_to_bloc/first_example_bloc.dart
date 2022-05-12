import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as devtools show log;

extension Log on Object {
  void log() => devtools.log(toString());
}

@immutable
abstract class LoadAction {
  const LoadAction();
}

@immutable
class LoadPersonsAction implements LoadAction {
  final PersonUrl url;
  const LoadPersonsAction({required this.url}) : super();
}

enum PersonUrl {
  person1,
  person2,
}

extension UrlString on PersonUrl {
  String get urlString {
    switch (this) {
      case PersonUrl.person1:
        return "http://127.0.0.1:5500/api/persons1.json";
      case PersonUrl.person2:
        return "http://127.0.0.1:5500/api/persons2.json";
    }
  }
}

@immutable
class Person {
  final String name;
  final int age;

  const Person({
    required this.name,
    required this.age,
  });

  Person.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        age = json['age'] as int;

  @override
  String toString() => "Person(name: $name, age: $age)";
}

Future<Iterable<Person>> getPersons(String url) => HttpClient()
    .getUrl(Uri.parse(url))
    .then((req) => req.close())
    .then((res) => res.transform(utf8.decoder).join())
    .then((str) => json.decode(str) as List<dynamic>)
    .then((list) => list.map((e) => Person.fromJson(e)));

@immutable
class FetchResult {
  final Iterable<Person> persons;
  final bool isRetrievedFromCache;

  const FetchResult({
    required this.persons,
    required this.isRetrievedFromCache,
  });

  @override
  String toString() =>
      "FetchResults (isRetrievedFromCache: $isRetrievedFromCache), persons: $persons";
}

class PersonsBloc extends Bloc<LoadAction, FetchResult?> {
  final Map<PersonUrl, Iterable<Person>> _cache = {};
  PersonsBloc() : super(null) {
    on<LoadPersonsAction>(
      (event, emit) async {
        final url = event.url;
        if (_cache.containsKey(url)) {
          final _cachedPersons = _cache[url]!;
          final result =
              FetchResult(persons: _cachedPersons, isRetrievedFromCache: true);
          emit(result);
        } else {
          final persons = await getPersons(url.urlString);
          _cache[url] = persons;
          final result =
              FetchResult(persons: persons, isRetrievedFromCache: false);
          emit(result);
        }
      },
    );
  }
}

extension Subscript<T> on Iterable<T> {
  T? operator [](int index) => length > index ? elementAt(index) : null;
}

class FirstExampleBloc extends StatelessWidget {
  FirstExampleBloc({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('First Example Bloc'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  context
                      .read<PersonsBloc>()
                      .add(const LoadPersonsAction(url: PersonUrl.person1));
                },
                child: const Text(
                  "Load json #1",
                ),
              ),
              TextButton(
                onPressed: () {
                  context
                      .read<PersonsBloc>()
                      .add(const LoadPersonsAction(url: PersonUrl.person2));
                },
                child: const Text(
                  "Load json #2",
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: BlocBuilder<PersonsBloc, FetchResult?>(
              buildWhen: (previous, current) =>
                  previous?.persons != current?.persons,
              builder: (context, fetchResults) {
                fetchResults?.log();
                final persons = fetchResults?.persons;
                if (persons == null) {
                  return const Text("Loading...");
                }
                return Container(
                  height: MediaQuery.of(context).size.height * 0.8,
                  width: double.maxFinite,
                  child: ListView.builder(
                      itemCount: persons.length,
                      itemBuilder: (context, index) {
                        final person = persons[index];
                        return ListTile(
                          title: Text(person!.name),
                          subtitle: Text(
                            person.age.toString(),
                          ),
                        );
                      }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
