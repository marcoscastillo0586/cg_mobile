import '../entities/ticket_parse_result.dart';

abstract class TicketReader {
  String get readerName;
  Future<TicketParseResult> processTicketImages(List<String> imagePaths);
}
