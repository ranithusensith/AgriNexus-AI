/// One page of a paginated Module 3 list (`{items, total, page, page_size}`).
class PageResult<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  const PageResult({required this.items, required this.total, required this.page, required this.pageSize});

  factory PageResult.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) => PageResult(
        items: (json['items'] as List<dynamic>).map((e) => parse(e as Map<String, dynamic>)).toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        pageSize: json['page_size'] as int,
      );

  bool get hasMore => page * pageSize < total;
}
