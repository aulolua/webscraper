import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

void main() async {
  var websiteUrl = await getInput('Enter the website URL: ');
  var outputDirectory = await getInput('Enter the output directory: ');

  await extractSourceCode(websiteUrl, outputDirectory);

  print('Extraction complete!');
}

Future<String> getInput(String prompt) {
  stdout.write(prompt);
  return Future(() => stdin.readLineSync()!);
}

Future<void> extractSourceCode(String url, String outputDir) async {
  await Directory(outputDir).create(recursive: true);

  var dio = Dio();
  var response = await dio.get(url);
  while (response.statusCode! >= 300 && response.statusCode! < 400) {
    // Follow redirection
    url = response.headers['location']![0];
    response = await dio.get(url);
  }

  var document = parser.parse(response.data);

  // Save the main HTML file
  var mainHtmlFilePath = '$outputDir/index.html';
  await File(mainHtmlFilePath).writeAsString(response.data);
  print('Saved HTML: $url');

  // Extract and download CSS files
  var cssLinks = document.querySelectorAll('link[rel="stylesheet"]');
  for (var link in cssLinks) {
    var cssUrl = link.attributes['href'];
    if (!cssUrl!.startsWith('http')) {
      cssUrl = Uri.parse(url).resolve(cssUrl).toString();
    }
    await downloadFile(cssUrl, outputDir);
  }

  // Extract and download JS files
  var jsScripts = document.querySelectorAll('script[src]');
  for (var script in jsScripts) {
    var jsUrl = script.attributes['src'];
    if (!jsUrl!.startsWith('http')) {
      jsUrl = Uri.parse(url).resolve(jsUrl).toString();
    }
    await downloadFile(jsUrl, outputDir);
  }

  // Extract and download image files
  var images = document.querySelectorAll('img[src]');
  for (var image in images) {
    var imgUrl = image.attributes['src'];
    if (!imgUrl!.startsWith('http')) {
      imgUrl = Uri.parse(url).resolve(imgUrl).toString();
    }
    await downloadFile(imgUrl, outputDir);
  }
}

Future<void> downloadFile(String url, String outputDir) async {
  try {
    var dio = Dio();
    var response = await dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    var filename = url.split('/').last;
    var outputFilePath = '$outputDir/${Uri.parse(filename).pathSegments.last}';
    await File(outputFilePath).writeAsBytes(response.data);
    print('Downloaded: $url');
  } catch (error) {
    print('Failed to download: $url');
    print(error);
  }
}
