import 'package:flutter/material.dart';
import 'package:searchbase/searchbase.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_searchbox/flutter_searchbox.dart';
import 'results.dart';
import 'author_filter.dart';
void main() {
  runApp(FlutterSearchBoxApp());
}
class FlutterSearchBoxApp extends StatelessWidget {
  // Avoid creating searchbase instance in build method
  // to preserve state on hot reloading
  final searchbaseInstance = SearchBase(
      'good-books-ds',
      'https://arc-cluster-appbase-demo-6pjy6z.searchbase.io',
      'a03a1cb71321:75b6603d-9456-4a5a-af6b-a487b309eb61',
      appbaseConfig: AppbaseSettings(
          recordAnalytics: true,
          // Use unique user id to personalize the recent searches
          userId: 'jon@appbase.io'));
  FlutterSearchBoxApp({Key key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    // The SearchBaseProvider should wrap your MaterialApp or WidgetsApp. This will
    // ensure all routes have access to the store.
    return SearchBaseProvider(
      // Pass the searchbase instance to the SearchBaseProvider. Any ancestor `SearchWidgetConnector`
      // Widgets will find and use this value as the `SearchWidget`.
      searchbase: searchbaseInstance,
      child: MaterialApp(
        title: "SearchBox Demo",
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: HomePage(),
      ),
    );
  }
}
class HomePage extends StatelessWidget {
  final TextEditingController _typeAheadController = TextEditingController();
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SearchBox Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
          appBar: AppBar(
            title: Text('SearchBox Demo'),
          ),
          body: Column(children: <Widget>[
            SearchWidgetConnector(
              id: 'search-widget',
              enablePopularSuggestions: true,
              maxPopularSuggestions: 3,
              triggerQueryOnInit: false,
              size: 5,
              subscribeTo: [],
              dataField: [
                {'field': 'original_title', 'weight': 1},
                {'field': 'original_title.search', 'weight': 3}
              ],
              builder: (context, searchWidget) => TypeAheadField(
                textFieldConfiguration: TextFieldConfiguration(
                    style: DefaultTextStyle.of(context)
                        .style
                        .copyWith(fontStyle: FontStyle.italic),
                    controller: this._typeAheadController,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Search for books")),
                suggestionsCallback: (pattern) async {
                  // Set value to search widget
                  searchWidget.setValue(pattern);
                  // If value is empty display recent searches as suggestions
                  if (pattern == "") {
                    return await searchWidget.getRecentSearches();
                  }
                  // Trigger suggestions query
                  await searchWidget.triggerDefaultQuery();
                  // Return suggestions
                  return searchWidget.suggestions;
                },
                itemBuilder: (context, Suggestion suggestion) {
                  return ListTile(
                    leading: suggestion.isRecentSearch
                        ? Icon(Icons.history)
                        : suggestion.isPopularSuggestion
                            ? Icon(Icons.trending_up)
                            : Icon(Icons.search),
                    title: Text(suggestion.label),
                  );
                },
                onSuggestionSelected: (Suggestion suggestion) {
                  // Set controller value
                  this._typeAheadController.text = suggestion.value;
                  // Set suggestion value to searchWidget
                  // and trigger custom query so watcher components can update
                  searchWidget.setValue(suggestion.value,
                      options: Options(triggerCustomQuery: true));
                  // trigger suggestion click analytics
                  try {
                    String objectId;
                    if (suggestion.source != null &&
                        suggestion.source['_id'] != null) {
                      objectId = suggestion.source['_id'].toString();
                    }
                    if (objectId != "" && suggestion.clickId != null) {
                      searchWidget.recordClick({objectId: suggestion.clickId},
                          isSuggestionClick: true);
                    }
                  } catch (e) {
                    print(e);
                  }
                },
              ),
            ),
            Expanded(
              // A custom UI widget to render a list of results
              child: SearchWidgetConnector(
                  id: 'result-widget',
                  dataField: 'original_title',
                  react: {
                    'and': ['search-widget', 'author-filter'],
                  },
                  size: 10,
                  triggerQueryOnInit: true,
                  preserveResults: true,
                  builder: (context, searchWidget) =>
                      ResultsWidget(searchWidget)),
            ),
          ]),
          // A custom UI widget to render a list of authors
          drawer: SearchWidgetConnector(
            id: 'author-filter',
            type: QueryType.term,
            dataField: "authors.keyword",
            size: 10,
            // Initialize with default value
            value: List<String>(),
            react: {
              'and': ['search-widget']
            },
            builder: (context, searchWidget) {
              // Call searchWidget's query at first time
              if (searchWidget.query == null) {
                searchWidget.triggerDefaultQuery();
              }
              return AuthorFilter(searchWidget);
            },
            // Avoid fetching query for each open/close action instead call it manually
            triggerQueryOnInit: false,
          )),
    );
  }
}