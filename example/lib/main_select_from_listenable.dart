import 'package:flutter/material.dart';
import 'package:implicit_navigator/implicit_navigator.dart';

/// This is a version of the Flutter Navigator 2.0 tutorial (sans routing logic)
/// rebuilt using Implicit Navigator's `selectFromListenable` method!
///
/// See:
/// * https://medium.com/flutter/learning-flutters-new-navigation-and-routing-system-7c9068155ade
/// * https://gist.github.com/johnpryan/72430e4abccf03ebb22c6080d796e84a#file-main-dart
///
/// Note the significant reduction in boilerplate (no Page/PageRoute classes!)
/// and improved readability relative to the original gist.
void main() {
  runApp(BooksApp());
}

class Book {
  const Book(this.title, this.author);

  final String title;
  final String author;
}

class BooksApp extends StatelessWidget {
  final SelectedBook _selectedBook = SelectedBook(null);

  static const List<Book> books = [
    Book('Left Hand of Darkness', 'Ursula K. Le Guin'),
    Book('Too Like the Lightning', 'Ada Palmer'),
    Book('Kindred', 'Octavia E. Butler'),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Books App',
      home: ImplicitNavigator.selectFromListenable<SelectedBook, Book?>(
        listenable: _selectedBook,
        selector: () => _selectedBook._book,
        builder: (context, book, animation, secondaryAnimation) {
          if (book == null) {
            return BooksListScreen(
              books: books,
              onTapped: (newBook) => _selectedBook.book = newBook,
            );
          }
          return BookDetailsScreen(
            key: ValueKey(_selectedBook),
            book: book,
          );
        },
        onPop: (poppedBook, bookAfterPop) => _selectedBook.book = bookAfterPop,
        transitionsBuilder: ImplicitNavigator.materialRouteTransitionsBuilder,
      ),
    );
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
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          for (var book in books)
            ListTile(
              title: Text(book.title),
              subtitle: Text(book.author),
              onTap: () => onTapped(book),
            )
        ],
      ),
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
    return Scaffold(
      appBar: AppBar(leading: const ImplicitNavigatorBackButton()),
      body: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.title, style: Theme.of(context).textTheme.headline6),
            Text(book.author, style: Theme.of(context).textTheme.subtitle1),
          ],
        ),
      ),
    );
  }
}

class SelectedBook extends ChangeNotifier {
  SelectedBook(this._book);

  Book? _book;

  Book? get book => _book;

  set book(Book? newBook) {
    _book = newBook;
    notifyListeners();
  }
}
