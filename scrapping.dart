import 'dart:collection';

import 'package:collection/collection.dart';

import 'package:args/args.dart';
import 'package:dotenv/dotenv.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:intl/intl.dart';

import './async.dart';

final importedItem = HashSet<String>();
final logFlags = {
  'itemPageDetail': false,
};

var noCreate = false;

void main(List<String> argStrs) async {
  // read args
  var argParser = ArgParser();
  // argParser.addOption('mode');
  // argParser.addFlag('verbose', defaultsTo: true);
  argParser.addFlag('nocreate', defaultsTo: false);
  var args = argParser.parse(argStrs);
  // print(args['mode']);
  // print(args['verbose']);
  noCreate = args['nocreate'];

  // read env
  var env = DotEnv(includePlatformEnvironment: true)..load();

  var appId = env['PARSE_SERVER_APPLICATION_ID']!;
  if (appId == "") appId = 'appId';
  var parseServerUrl = env['PARSE_SERVER_URL']!;
  if (parseServerUrl == "") parseServerUrl = 'http://localhost:1337/parse';
  await Parse().initialize(
    appId,
    parseServerUrl,
  );

  // await test();
  
  // final itemUrls = await scrapeRetiringSoon();
  final itemUrls = [ "/set/30635-1/lego-friends-cleanup" ];

  await eachLimit(itemUrls, 10, (String? itemUrl) async {
  // var element = document.querySelector('td.ctlsets-left');
    if (itemUrl == null) return;
    print(itemUrl);
    await scrapeItemPage(itemUrl);
  });
}

Future<Iterable<String?>> scrapeRetiringSoon() async {
  final uri = Uri.https('www.brickeconomy.com', '/sets/retiring-soon');
  var response = await http.get(uri);
  var document = parser.parse(response.body);
  // get main list

  final itemUrls = document.querySelectorAll('td.ctlsets-left').map((element) => element.querySelector('a')?.attributes['href']);
  return itemUrls;
}

Future<void> scrapeItemPage(String itemUrl) async {
  final CollectionName = 'BrickEconomySet2023';
  final regex = RegExp(r'\d+-\d+');
  final digitRegExp = RegExp(r'\d+');
  final floatRegExp = RegExp(r'[\d.]+');

  final itemKey = regex.firstMatch(itemUrl)?.group(0);
  // print (itemKey);

  // assert(itemKey != null, 'invalid item url $itemUrl');
  if (itemKey == null) {
    print('invalid item url $itemUrl');
    return;
  }
  if (!importedItem.add(itemKey)) return;
  final uri = Uri.https('www.brickeconomy.com', itemUrl);
  final response = await http.get(uri);
  final document = parser.parse(response.body);
  final divs = document.getElementsByTagName('div');

  // find or create parse object
  var query = QueryBuilder<ParseObject>(ParseObject(CollectionName));
  query.whereEqualTo('key', itemKey);
  var parseObj = await query.first();
  if (parseObj == null) {
    print('add item page $itemKey');
    // create new object
    if (logFlags['itemPageDetail']!) print('create new object');
    parseObj = ParseObject(CollectionName)..set('key', itemKey);
  } else if (noCreate) {
  } else {
    print('update item page $itemKey');
    if (logFlags['itemPageDetail']!) print('get old object ${parseObj.objectId}');
  }

  Element? tarEle;
  String value;
  DateTime dateValue;
  // set number
  // TODO: handle error
  // TODO: firstOrNull
  tarEle = divs.firstWhere((element) => element.innerHtml == 'Set number');
  value = tarEle.nextElementSibling!.text;
  if (logFlags['itemPageDetail']!) print('setNumber $value');
  parseObj.set('setNumber', value);
  
  // Name
  tarEle = divs.firstWhere((element) => element.innerHtml == 'Name');
  value = tarEle.nextElementSibling!.text;
  if (logFlags['itemPageDetail']!) print('name $value');
  parseObj.set('name', value);
  
  // Theme
  tarEle = divs.firstWhere((element) => element.innerHtml == 'Theme');
  value = tarEle.nextElementSibling!.text;
  if (logFlags['itemPageDetail']!) print('theme $value');
  parseObj.set('theme', value);
  
  // Subtheme
  tarEle = divs.firstWhereOrNull((element) => element.innerHtml == 'Subtheme');
  if (tarEle != null) {
    value = tarEle.nextElementSibling!.text;
    if (logFlags['itemPageDetail']!) print('subtheme $value');
    parseObj.set('subtheme', value);
  }
  
  // Year
  tarEle = divs.firstWhere((element) => element.innerHtml == 'Year');
  value = tarEle.nextElementSibling!.text;
  if (logFlags['itemPageDetail']!) print('year $value');
  parseObj.set('year', int.parse(value));
  
  // Released
  tarEle = divs.firstWhere((element) => element.innerHtml == 'Released');
  value = tarEle.nextElementSibling!.text;
  try {
    dateValue = DateFormat.yMMMMd('en_US').parse(value);
  } catch (e) {
    dateValue = DateFormat.yMMMM('en_US').parse(value);
  }
  if (logFlags['itemPageDetail']!) print('year $value $dateValue');
  parseObj.set('year', dateValue);
  
  // Availability
  tarEle = divs.firstWhereOrNull((element) => element.innerHtml == 'Availability');
  if (tarEle != null) {
    value = tarEle.nextElementSibling!.text;
    if (logFlags['itemPageDetail']!) print('availability $value');
    parseObj.set('availability', value);
  }
  
  // Pieces
  tarEle = divs.firstWhere((element) => element.innerHtml == 'Pieces');
  value = tarEle.nextElementSibling!.text;
  value = digitRegExp.firstMatch(value)!.group(0)!;
  if (logFlags['itemPageDetail']!) print('pieces $value');
  parseObj.set('pieces', int.parse(value));
  
  // Retail price
  tarEle = divs.firstWhere((element) => element.innerHtml == 'Retail price');
  value = tarEle.nextElementSibling!.text;
  if (value.contains('Free')) {
    parseObj.set('isFree', true);
  } else {
    parseObj.set('isFree', false);
    final matches = floatRegExp.firstMatch(value);
    if (matches != null) {
      value = matches.group(0)!;
      if (logFlags['itemPageDetail']!) print('retailPrice $value');
      parseObj.set('retailPrice', double.parse(value));
    }
  }

  // Market price
  tarEle = null;
  try {
    tarEle = divs.firstWhere((element) => element.text == 'Market price');
  } catch (_) {}
  if (tarEle != null) {
    value = tarEle.nextElementSibling!.text;
    value = floatRegExp.firstMatch(value)!.group(0)!;
    if (logFlags['itemPageDetail']!) print('marketPrice $value');
    parseObj.set('marketPrice', double.parse(value));
  }
  
  // Value
  tarEle = null;
  try {
    tarEle = divs.firstWhere((element) => element.text == 'Value');
  } catch (_) {}
  if (tarEle != null) {
    value = tarEle.nextElementSibling!.text;
    value = floatRegExp.firstMatch(value)!.group(0)!;
    if (logFlags['itemPageDetail']!) print('value $value');
    parseObj.set('value', double.parse(value));
  }

  // brick economy choice
  final becEle = document.querySelector('tr.table-row-highlight');
  if (becEle != null) {
    // verification
    if (becEle.querySelectorAll('small')[1].text != 'BrickEconomy Choice') {
      print('error when parsing brick economy choice: $itemKey');
    } else {
      var (store, price) = scrapeItemPagePriceRecord(becEle);
    if (logFlags['itemPageDetail']!) print('beChoiceStore $store');
    if (logFlags['itemPageDetail']!) print('beChoicePrice $price');
      parseObj.set('beChoiceStore', store);
      parseObj.set('beChoicePrice', price);
    }
  }
  
  // lowest price in the list
  tarEle = document.querySelector('table#sales_region_table tr');
  if (tarEle != null) {
    if (tarEle == becEle) {
      print('bec is lowest: $itemKey');
    }
    var (store, price) = scrapeItemPagePriceRecord(tarEle);
    if (logFlags['itemPageDetail']!) print('lowestStore $store');
    if (logFlags['itemPageDetail']!) print('lowestPrice $price');
    parseObj.set('lowestStore', store);
    parseObj.set('lowestPrice', price);
  }

  await parseObj.save();
}

(String, double) scrapeItemPagePriceRecord(tarEle) {
  // store
  var tarEle2 = tarEle.querySelector('td div');
  var store = tarEle2!.className.replaceFirst('set-sale-', '');
  // price
  tarEle2 = tarEle.querySelector('span');
  var price = double.parse(tarEle2!.text.replaceFirst('\$', '').replaceFirst('~', ''));
  return (store, price);
}
