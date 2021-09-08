import 'package:flutter/material.dart';
import 'package:implicit_navigator/implicit_navigator.dart';

/// This is a version of the Flutter Navigator 2.0 tutorial (sans routing logic)
/// rebuilt using Implicit Navigator!
///
/// See:
/// * https://medium.com/flutter/learning-flutters-new-navigation-and-routing-system-7c9068155ade
/// * https://gist.github.com/johnpryan/72430e4abccf03ebb22c6080d796e84a#file-main-dart
///
/// Note the significant reduction in boilerplate (no Page/PageRoute classes!)
/// and improved readability relative to the original gist above.
void main() {
  runApp(BooksApp());
}

class Book {
  const Book(this.title, this.author);

  final String title;
  final String author;
}

class BooksApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _BooksAppState();
}

class _BooksAppState extends State<BooksApp> {
  Book? _selectedBook;

  static const List<Book> books = [
    Book('Left Hand of Darkness', 'Ursula K. Le Guin'),
    Book('Too Like the Lightning', 'Ada Palmer'),
    Book('Kindred', 'Octavia E. Butler'),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Books App',
      home: Scaffold(
        appBar: AppBar(leading: const ImplicitNavigatorBackButton()),
        body: ImplicitNavigator<Book?>(
          value: _selectedBook,
          builder: (context, book, animation, secondaryAnimation) {
            if (book == null) {
              return BooksListScreen(
                books: books,
                onTapped: _handleBookTapped,
              );
            }
            return BookDetailsScreen(
              key: ValueKey(_selectedBook),
              book: book,
            );
          },
          transitionsBuilder: ImplicitNavigator.materialRouteTransitionsBuilder,
          onPop: (poppedBook, currentBook) {
            _selectedBook = currentBook;
          },
        ),
      ),
    );
  }

  void _handleBookTapped(Book book) {
    setState(() {
      _selectedBook = book;
    });
  }
}

class BooksListScreen extends StatelessWidget {
  const BooksListScreen({
    required this.books,
    required this.onTapped,
  });

  final List<Book> books;
  final ValueChanged<Book> onTapped;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (var book in books)
          ListTile(
            title: Text(book.title),
            subtitle: Text(book.author),
            onTap: () => onTapped(book),
          )
      ],
    );
  }
}

class BookDetailsScreen extends StatelessWidget {
  const BookDetailsScreen({
    Key? key,
    required this.book,
  }) : super(key: key);

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(book.title, style: Theme.of(context).textTheme.headline6),
          Text(book.author, style: Theme.of(context).textTheme.subtitle1),
        ],
      ),
    );
  }
}
