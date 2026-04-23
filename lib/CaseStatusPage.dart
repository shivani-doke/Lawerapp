import 'package:flutter/material.dart';

import 'services/api_service.dart';

class CaseStatusPage extends StatefulWidget {
  const CaseStatusPage({super.key});

  @override
  State<CaseStatusPage> createState() => _CaseStatusPageState();
}

enum _CaseSearchMode { cnr, advocate }

class _CaseStatusPageState extends State<CaseStatusPage> {
  static const List<String> _defaultCaseStatusOptions = <String>[
    'DISPOSED',
    'PENDING',
  ];

  final ApiService _apiService = ApiService();
  final TextEditingController _advocateController = TextEditingController();
  final TextEditingController _courtCodeController = TextEditingController();
  final TextEditingController _filingDateFromController =
      TextEditingController();
  final TextEditingController _filingDateToController = TextEditingController();
  final TextEditingController _cnrController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedCaseStatus;
  _CaseSearchMode _searchMode = _CaseSearchMode.cnr;
  int _currentPage = 1;
  final int _pageSize = 20;

  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];
  Map<String, dynamic> _pagination = <String, dynamic>{};
  Map<String, dynamic> _facets = <String, dynamic>{};
  Map<String, dynamic>? _caseDetail;

  @override
  void dispose() {
    _advocateController.dispose();
    _courtCodeController.dispose();
    _filingDateFromController.dispose();
    _filingDateToController.dispose();
    _cnrController.dispose();
    super.dispose();
  }

  Future<void> _searchCases({int page = 1}) async {
    final advocateName = _advocateController.text.trim();
    if (advocateName.isEmpty) {
      setState(() {
        _errorMessage = 'Enter an advocate name to search cases.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _caseDetail = null;
    });

    try {
      final response = await _apiService.fetchCasesByAdvocate(
        advocates: advocateName,
        courtCodes: _courtCodeController.text,
        filingDateFrom: _filingDateFromController.text,
        filingDateTo: _filingDateToController.text,
        caseStatus: _selectedCaseStatus,
        page: page,
        pageSize: _pageSize,
      );

      final rawResults = response['results'];
      final parsedResults = rawResults is List
          ? rawResults
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _results = parsedResults;
        _pagination = response['pagination'] is Map
            ? Map<String, dynamic>.from(response['pagination'])
            : <String, dynamic>{};
        _facets = response['facets'] is Map
            ? Map<String, dynamic>.from(response['facets'])
            : <String, dynamic>{};
        _currentPage = (_pagination['page'] as num?)?.toInt() ?? page;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchByCnr() async {
    final cnr = _cnrController.text.trim();
    if (cnr.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a CNR number to load case detail.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results = <Map<String, dynamic>>[];
      _pagination = <String, dynamic>{};
      _facets = <String, dynamic>{};
    });

    try {
      final response = await _apiService.fetchCaseByCnr(cnr);
      setState(() {
        _caseDetail = response;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _advocateController.clear();
      _courtCodeController.clear();
      _filingDateFromController.clear();
      _filingDateToController.clear();
      _cnrController.clear();
      _selectedCaseStatus = null;
      _results = <Map<String, dynamic>>[];
      _pagination = <String, dynamic>{};
      _facets = <String, dynamic>{};
      _caseDetail = null;
      _errorMessage = null;
      _currentPage = 1;
    });
  }

  List<String> _facetOptions(String facetName) {
    final facet = _facets[facetName];
    if (facet is! Map) {
      return const <String>[];
    }
    final values = facet['values'];
    if (values is! Map) {
      return const <String>[];
    }
    return values.keys.map((key) => key.toString()).toList()..sort();
  }

  List<String> _caseStatusOptions() {
    final combined = <String>{
      ..._defaultCaseStatusOptions,
      ..._facetOptions('caseStatus'),
    };
    final sorted = combined.toList()..sort();
    return sorted;
  }

  String _joinList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).join(', ');
    }
    return (value ?? '').toString();
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    if (value is Map) {
      return value.isNotEmpty;
    }
    return true;
  }

  String _formatDisplayValue(dynamic value) {
    if (value == null) {
      return 'Not available';
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    if (value is List) {
      final joined = _joinList(value).trim();
      return joined.isEmpty ? 'Not available' : joined;
    }
    final text = value.toString().trim();
    return text.isEmpty ? 'Not available' : text;
  }

  Widget _buildSearchCard() {
    final caseStatusOptions = _caseStatusOptions();
    final isAdvocateMode = _searchMode == _CaseSearchMode.advocate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search Cases',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isAdvocateMode
                ? 'Choose advocate search to fetch matching case lists. You can optionally narrow the results with court code, dates, and case filters.'
                : 'Choose CNR search to load the full case detail for one exact case record.',
            style: const TextStyle(color: Color(0xff6b7280), height: 1.5),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xfff3f4f6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeButton(
                  label: 'By CNR',
                  mode: _CaseSearchMode.cnr,
                ),
                const SizedBox(width: 8),
                _buildModeButton(
                  label: 'By Advocate',
                  mode: _CaseSearchMode.advocate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (isAdvocateMode)
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildInputField(
                  controller: _advocateController,
                  label: 'Advocate Name',
                  hint: 'Adv. Rahul Sharma',
                  width: 320,
                ),
                _buildInputField(
                  controller: _courtCodeController,
                  label: 'Court Code',
                  hint: 'DLHC01',
                  width: 180,
                ),
                _buildInputField(
                  controller: _filingDateFromController,
                  label: 'Filing Date From',
                  hint: '2024-01-01',
                  width: 170,
                ),
                _buildInputField(
                  controller: _filingDateToController,
                  label: 'Filing Date To',
                  hint: '2024-12-31',
                  width: 170,
                ),
                _buildDropdownField(
                  label: 'Case Status',
                  value: _selectedCaseStatus,
                  options: caseStatusOptions,
                  width: 180,
                  onChanged: (value) {
                    setState(() {
                      _selectedCaseStatus = value;
                    });
                  },
                ),
              ],
            )
          else
            _buildInputField(
              controller: _cnrController,
              label: 'CNR Number',
              hint: 'DLHC010001232024',
              width: 320,
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff111827),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : () {
                        if (isAdvocateMode) {
                          _searchCases(page: 1);
                        } else {
                          _searchByCnr();
                        }
                      },
                icon: Icon(
                  isAdvocateMode ? Icons.search : Icons.find_in_page_outlined,
                ),
                label: Text(
                  isAdvocateMode ? 'Search Cases' : 'Load Case Detail',
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _resetFilters,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required _CaseSearchMode mode,
  }) {
    final isSelected = _searchMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isLoading
          ? null
          : () {
              setState(() {
                _searchMode = mode;
                _errorMessage = null;
                _results = <Map<String, dynamic>>[];
                _pagination = <String, dynamic>{};
                _facets = <String, dynamic>{};
                _caseDetail = null;
                _currentPage = 1;
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff111827) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xff374151),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xfff8fafc),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffd1d5db)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffd1d5db)),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required double width,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xfff8fafc),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffd1d5db)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffd1d5db)),
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildResultsSummary() {
    final totalHits = (_pagination['totalHits'] as num?)?.toInt() ?? 0;
    final totalPages = (_pagination['totalPages'] as num?)?.toInt() ?? 0;

    return Row(
      children: [
        Text(
          '$totalHits matches found',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xff111827),
          ),
        ),
        if (totalPages > 0) ...[
          const SizedBox(width: 12),
          Text(
            'Page $_currentPage of $totalPages',
            style: const TextStyle(color: Color(0xff6b7280)),
          ),
        ],
      ],
    );
  }

  Widget _buildResultsBody() {
    if (_errorMessage != null) {
      return _buildStateCard(
        icon: Icons.error_outline,
        title: 'Search unavailable',
        message: _errorMessage!,
      );
    }

    if (_isLoading && _results.isEmpty && _caseDetail == null) {
      return _buildStateCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Searching eCourts',
        message: 'Fetching case data from the partner API.',
        isLoading: true,
      );
    }

    if (_caseDetail != null) {
      return _buildCaseDetailViewOrganized();
    }

    if (_results.isEmpty) {
      return _buildStateCard(
        icon: Icons.fact_check_outlined,
        title: 'No results yet',
        message:
            'Run an advocate search or enter a CNR number to view case status, hearing dates, parties, and detailed case material here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultsSummary(),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = _results[index];
              return _buildResultCard(item);
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildPaginationControls(),
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    final statusLabel =
        (item['caseStatusLabel'] ?? item['caseStatus'] ?? 'Unknown').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffe5e7eb)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['cnr'] ?? 'Unknown CNR').toString(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(item['caseTypeLabel'] ?? item['caseType'] ?? 'Unknown').toString()} • ${(item['courtCodeLabel'] ?? item['courtCode'] ?? 'Unknown court').toString()}',
                      style: const TextStyle(color: Color(0xff6b7280)),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(statusLabel),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildInfoTile('Next Hearing', item['nextHearingDate']),
              _buildInfoTile('Filing Date', item['filingDate']),
              _buildInfoTile('Registration', item['registrationNumber']),
              _buildInfoTile('Decision Date', item['decisionDate']),
              _buildInfoTile('Judicial Section', item['judicialSectionLabel']),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabeledText('Petitioners', _joinList(item['petitioners'])),
          const SizedBox(height: 10),
          _buildLabeledText('Respondents', _joinList(item['respondents'])),
          const SizedBox(height: 10),
          _buildLabeledText('Advocates', _joinList(item['petitionerAdvocates'])),
          const SizedBox(height: 10),
          _buildLabeledText('Judges', _joinList(item['judges'])),
        ],
      ),
    );
  }

  Widget _buildCaseDetailViewImproved() {
    final detail = _caseDetail ?? <String, dynamic>{};
    final caseData = detail['courtCaseData'] is Map
        ? Map<String, dynamic>.from(detail['courtCaseData'])
        : <String, dynamic>{};
    final entityInfo = detail['entityInfo'] is Map
        ? Map<String, dynamic>.from(detail['entityInfo'])
        : <String, dynamic>{};
    final files = detail['files'] is List
        ? (detail['files'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final recommendedDocuments = detail['recommendedDocuments'] is List
        ? (detail['recommendedDocuments'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final caseAiAnalysis = detail['caseAiAnalysis'] is Map
        ? Map<String, dynamic>.from(detail['caseAiAnalysis'])
        : <String, dynamic>{};
    final hearingHistory = caseData['historyOfCaseHearings'] is List
        ? (caseData['historyOfCaseHearings'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final caseNumber =
        (caseData['caseNumber'] ?? caseData['cnr'] ?? 'Case Detail').toString();
    final caseType =
        (caseData['caseTypeLabel'] ?? caseData['caseType'] ?? '').toString().trim();
    final caseTypeRaw = (caseData['caseTypeRaw'] ?? '').toString().trim();
    final caseStatus =
        (caseData['caseStatusLabel'] ?? caseData['caseStatus'] ?? 'Unknown')
            .toString();
    final hasCaseIntelligence = _hasMeaningfulValue(caseAiAnalysis['caseSummary']) ||
        _hasMeaningfulValue(caseAiAnalysis['caseType']) ||
        _hasMeaningfulValue(caseAiAnalysis['complexity']) ||
        _hasMeaningfulValue(caseAiAnalysis['keyIssues']);
    final summaryTiles = <Widget>[
      if (_hasMeaningfulValue(caseData['nextHearingDate']))
        _buildInfoTile('Next Hearing', caseData['nextHearingDate']),
      if (_hasMeaningfulValue(caseData['stageOfCaseRaw'] ?? caseData['stageOfCase']))
        _buildInfoTile(
          'Stage',
          caseData['stageOfCaseRaw'] ?? caseData['stageOfCase'],
        ),
      if (_hasMeaningfulValue(caseData['lastHearingDate']))
        _buildInfoTile('Last Hearing', caseData['lastHearingDate']),
      if (_hasMeaningfulValue(caseData['firstHearingDate']))
        _buildInfoTile('First Hearing', caseData['firstHearingDate']),
      if (_hasMeaningfulValue(caseData['filingDate']))
        _buildInfoTile('Filing Date', caseData['filingDate']),
      if (_hasMeaningfulValue(caseData['registrationDate']))
        _buildInfoTile('Registration Date', caseData['registrationDate']),
      if (_hasMeaningfulValue(caseData['caseTypeSub']))
        _buildInfoTile('Acts / Sections', caseData['caseTypeSub']),
      if (_hasMeaningfulValue(caseData['purpose']))
        _buildInfoTile('Purpose', caseData['purpose']),
      if (_hasMeaningfulValue(caseData['hearingCount']))
        _buildInfoTile('Hearings', caseData['hearingCount']),
      if (_hasMeaningfulValue(caseData['caseDurationDays']))
        _buildInfoTile('Case Age', '${caseData['caseDurationDays']} days'),
      if (_hasMeaningfulValue(caseData['filingToFirstHearingDays']))
        _buildInfoTile(
          'Days To First Hearing',
          '${caseData['filingToFirstHearingDays']} days',
        ),
      if (_hasMeaningfulValue(caseData['registrationNumber']))
        _buildInfoTile('Registration No', caseData['registrationNumber']),
      if (_hasMeaningfulValue(caseData['filingNumber']))
        _buildInfoTile('Filing No', caseData['filingNumber']),
      if (_hasMeaningfulValue(caseData['courtNo']))
        _buildInfoTile('Court No', caseData['courtNo']),
      if (_hasMeaningfulValue(caseData['caseCategoryFacetPath']))
        _buildInfoTile('Category', caseData['caseCategoryFacetPath']),
      if (_hasMeaningfulValue(caseData['cnrCourtCode']))
        _buildInfoTile('CNR Court Code', caseData['cnrCourtCode']),
      if (_hasMeaningfulValue(caseData['courtComplexCode']))
        _buildInfoTile('Court Complex Code', caseData['courtComplexCode']),
      if (_hasMeaningfulValue(caseData['orderCount']))
        _buildInfoTile('Orders', caseData['orderCount']),
      if (_hasMeaningfulValue(caseData['judgmentCount']))
        _buildInfoTile('Judgments', caseData['judgmentCount']),
      if (_hasMeaningfulValue(caseData['interimOrderCount']))
        _buildInfoTile('Interim Orders', caseData['interimOrderCount']),
      if (_hasMeaningfulValue(caseData['iaCount']))
        _buildInfoTile('IA Count', caseData['iaCount']),
    ];

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [caseNumber, if (caseType.isNotEmpty) caseType].join(' | '),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(caseData['courtName'] ?? 'Unknown court').toString()} â€¢ ${(caseData['cnr'] ?? '').toString()}',
                          style: const TextStyle(color: Color(0xff6b7280)),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(caseStatus),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: summaryTiles,
              ),
              const SizedBox(height: 18),
              if (_hasMeaningfulValue(caseTypeRaw) && caseTypeRaw != caseType) ...[
                _buildLabeledText('Case Type Raw', caseTypeRaw),
                const SizedBox(height: 10),
              ],
              if (_hasMeaningfulValue(
                caseData['judicialSectionRaw'] ?? caseData['judicialSection'],
              )) ...[
                _buildLabeledText(
                  'Judicial Section',
                  _formatDisplayValue(
                    caseData['judicialSectionRaw'] ?? caseData['judicialSection'],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _buildListBlock('Petitioners', caseData['petitioners']),
              _buildListBlock(
                'Petitioner Advocates',
                caseData['petitionerAdvocates'],
              ),
              _buildListBlock('Respondents', caseData['respondents']),
              _buildListBlock(
                'Respondent Advocates',
                caseData['respondentAdvocates'],
              ),
              _buildListBlock('Judges', caseData['judges']),
              if (_hasMeaningfulValue(caseData['actsAndSections'])) ...[
                _buildLabeledText(
                  'Acts & Sections',
                  _formatDisplayValue(caseData['actsAndSections']),
                ),
                const SizedBox(height: 10),
              ],
              _buildLabeledText(
                'Location',
                '${(caseData['district'] ?? '').toString()} ${(caseData['state'] ?? '').toString()}'.trim(),
              ),
            ],
          ),
        ),
        if (hearingHistory.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildHearingHistoryCard(hearingHistory),
        ],
        if (hasCaseIntelligence) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Case Intelligence',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                _buildLabeledText(
                  'Summary',
                  _formatDisplayValue(caseAiAnalysis['caseSummary']),
                ),
                const SizedBox(height: 10),
                _buildLabeledText(
                  'Type',
                  _formatDisplayValue(caseAiAnalysis['caseType']),
                ),
                const SizedBox(height: 10),
                _buildLabeledText(
                  'Complexity',
                  _formatDisplayValue(caseAiAnalysis['complexity']),
                ),
                const SizedBox(height: 10),
                _buildLabeledText(
                  'Key Issues',
                  _joinList(caseAiAnalysis['keyIssues']),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Entity Info',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildInfoTile('Entity CNR', entityInfo['cnr']),
                  _buildInfoTile('Created', entityInfo['dateCreated']),
                  _buildInfoTile('Modified', entityInfo['dateModified']),
                  _buildInfoTile('Next Date', entityInfo['nextDateOfHearing']),
                  if (_hasMeaningfulValue(entityInfo['lastDateOfHearing']))
                    _buildInfoTile(
                      'Last Date',
                      entityInfo['lastDateOfHearing'],
                    ),
                  _buildInfoTile('Request ID', detail['requestId']),
                ],
              ),
            ],
          ),
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Orders And Files',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                ...files.map(_buildFileCard),
              ],
            ),
          ),
        ],
        if (recommendedDocuments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xfffffbeb),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xfff59e0b)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xffb45309),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Suggested Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff78350f),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'These drafts are suggested from the case detail, purpose, issues, and litigation context.',
                  style: TextStyle(color: Color(0xff92400e), height: 1.5),
                ),
                const SizedBox(height: 14),
                ...recommendedDocuments.map(_buildRecommendedDocumentCard),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCaseDetailViewOrganized() {
    final detail = _caseDetail ?? <String, dynamic>{};
    final caseData = detail['courtCaseData'] is Map
        ? Map<String, dynamic>.from(detail['courtCaseData'])
        : <String, dynamic>{};
    final entityInfo = detail['entityInfo'] is Map
        ? Map<String, dynamic>.from(detail['entityInfo'])
        : <String, dynamic>{};
    final files = detail['files'] is List
        ? (detail['files'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final hearingHistory = caseData['historyOfCaseHearings'] is List
        ? (caseData['historyOfCaseHearings'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final recommendedDocuments = detail['recommendedDocuments'] is List
        ? (detail['recommendedDocuments'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final caseAiAnalysis = detail['caseAiAnalysis'] is Map
        ? Map<String, dynamic>.from(detail['caseAiAnalysis'])
        : <String, dynamic>{};
    final caseTypeLabel = _formatDisplayValue(
      caseData['caseTypeRaw'] ?? caseData['caseTypeLabel'] ?? caseData['caseType'],
    );
    final caseStage = _formatDisplayValue(
      caseData['stageOfCaseRaw'] ?? caseData['stageOfCase'] ?? caseData['purpose'],
    );
    final judges = caseData['judges'] is List
        ? (caseData['judges'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final petitioners = caseData['petitioners'] is List
        ? (caseData['petitioners'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final petitionerAdvocates = caseData['petitionerAdvocates'] is List
        ? (caseData['petitionerAdvocates'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final respondents = caseData['respondents'] is List
        ? (caseData['respondents'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final respondentAdvocates = caseData['respondentAdvocates'] is List
        ? (caseData['respondentAdvocates'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final hasCaseIntelligence = _hasMeaningfulValue(caseAiAnalysis['caseSummary']) ||
        _hasMeaningfulValue(caseAiAnalysis['caseType']) ||
        _hasMeaningfulValue(caseAiAnalysis['complexity']) ||
        _hasMeaningfulValue(caseAiAnalysis['keyIssues']);
    final actsAndSections = _formatDisplayValue(
      caseData['caseTypeSub'] ?? caseData['actsAndSections'],
    );
    final actsParts = actsAndSections == 'Not available'
        ? <String, String>{'acts': 'Not available', 'sections': 'Not available'}
        : _splitActsAndSections(actsAndSections);

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _caseDetail = null;
                              _errorMessage = null;
                            });
                          },
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Back to Search'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatDisplayValue(caseData['courtName']),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatusChip(
                    _formatDisplayValue(
                      caseData['caseStatusLabel'] ?? caseData['caseStatus'],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSectionHeading('Case Details'),
              _buildStructuredTable(
                rows: [
                  _StructuredRow.full('Case Type', caseTypeLabel),
                  _StructuredRow.pair(
                    'Filing Number',
                    _formatDisplayValue(caseData['filingNumber']),
                    'Filing Date',
                    _formatDisplayValue(caseData['filingDate']),
                  ),
                  _StructuredRow.pair(
                    'Registration Number',
                    _formatDisplayValue(caseData['registrationNumber']),
                    'Registration Date',
                    _formatDisplayValue(caseData['registrationDate']),
                  ),
                  _StructuredRow.full(
                    'CNR Number',
                    _formatDisplayValue(caseData['cnr']),
                  ),
                  _StructuredRow.pair(
                    'Court Code',
                    _formatDisplayValue(caseData['cnrCourtCode']),
                    'Court Complex Code',
                    _formatDisplayValue(caseData['courtComplexCode']),
                  ),
                  _StructuredRow.full(
                    'Case Number',
                    _formatDisplayValue(caseData['caseNumber']),
                  ),
                  _StructuredRow.pair(
                    'Last Hearing',
                    _formatDisplayValue(caseData['lastHearingDate']),
                    'Hearings',
                    _formatDisplayValue(caseData['hearingCount']),
                  ),
                  _StructuredRow.pair(
                    'Case Age',
                    _hasMeaningfulValue(caseData['caseDurationDays'])
                        ? '${caseData['caseDurationDays']} days'
                        : 'Not available',
                    'Location',
                    '${(caseData['district'] ?? '').toString()} ${(caseData['state'] ?? '').toString()}'.trim().isEmpty
                        ? 'Not available'
                        : '${(caseData['district'] ?? '').toString()} ${(caseData['state'] ?? '').toString()}'.trim(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionHeading('Case Status'),
              _buildStructuredTable(
                rows: [
                  _StructuredRow.single(
                    'First Hearing Date',
                    _formatDisplayValue(caseData['firstHearingDate']),
                  ),
                  _StructuredRow.single(
                    'Next Hearing Date',
                    _formatDisplayValue(caseData['nextHearingDate']),
                  ),
                  _StructuredRow.single('Case Stage', caseStage),
                  _StructuredRow.single(
                    'Court Number and Judge',
                    [
                      if (_hasMeaningfulValue(caseData['courtNo']))
                        _formatDisplayValue(caseData['courtNo']),
                      if (judges.isNotEmpty) judges.first,
                    ].join(' - '),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionHeading('Petitioner and Advocate'),
              _buildPartySection(
                parties: petitioners,
                advocates: petitionerAdvocates,
              ),
              const SizedBox(height: 20),
              _buildSectionHeading('Respondent and Advocate'),
              _buildPartySection(
                parties: respondents,
                advocates: respondentAdvocates,
                repeatAdvocatesPerParty: respondentAdvocates.length == 1,
              ),
              const SizedBox(height: 20),
              _buildSectionHeading('Acts'),
              _buildStructuredTable(
                rows: [
                  _StructuredRow.pair(
                    'Under Act(s)',
                    actsParts['acts'] ?? 'Not available',
                    'Under Section(s)',
                    actsParts['sections'] ?? 'Not available',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (hearingHistory.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildHearingHistoryCard(hearingHistory),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Entity Info',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildInfoTile('CNR', entityInfo['cnr']),
                  _buildInfoTile('Next Date Of Hearing', entityInfo['nextDateOfHearing']),
                  _buildInfoTile('Last Date Of Hearing', entityInfo['lastDateOfHearing']),
                  _buildInfoTile('Date Created', entityInfo['dateCreated']),
                  _buildInfoTile('Date Modified', entityInfo['dateModified']),
                ],
              ),
            ],
          ),
        ),
        if (hasCaseIntelligence) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Case Intelligence',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                _buildLabeledText(
                  'Summary',
                  _formatDisplayValue(caseAiAnalysis['caseSummary']),
                ),
                const SizedBox(height: 10),
                _buildLabeledText(
                  'Type',
                  _formatDisplayValue(caseAiAnalysis['caseType']),
                ),
                const SizedBox(height: 10),
                _buildLabeledText(
                  'Complexity',
                  _formatDisplayValue(caseAiAnalysis['complexity']),
                ),
                const SizedBox(height: 10),
                _buildLabeledText(
                  'Key Issues',
                  _joinList(caseAiAnalysis['keyIssues']),
                ),
              ],
            ),
          ),
        ],
        if (files.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Orders And Files',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                ...files.map(_buildFileCard),
              ],
            ),
          ),
        ],
        if (recommendedDocuments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xfffffbeb),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xfff59e0b)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xffb45309),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Suggested Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff78350f),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'These drafts are suggested from the case detail, purpose, issues, and litigation context.',
                  style: TextStyle(color: Color(0xff92400e), height: 1.5),
                ),
                const SizedBox(height: 14),
                ...recommendedDocuments.map(_buildRecommendedDocumentCard),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCaseDetailView() {
    final detail = _caseDetail ?? <String, dynamic>{};
    final caseData = detail['courtCaseData'] is Map
        ? Map<String, dynamic>.from(detail['courtCaseData'])
        : <String, dynamic>{};
    final entityInfo = detail['entityInfo'] is Map
        ? Map<String, dynamic>.from(detail['entityInfo'])
        : <String, dynamic>{};
    final files = detail['files'] is List
        ? (detail['files'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final recommendedDocuments = detail['recommendedDocuments'] is List
        ? (detail['recommendedDocuments'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final caseAiAnalysis = detail['caseAiAnalysis'] is Map
        ? Map<String, dynamic>.from(detail['caseAiAnalysis'])
        : <String, dynamic>{};
    final caseNumber = (caseData['caseNumber'] ?? caseData['cnr'] ?? 'Case Detail')
        .toString();
    final caseType = (caseData['caseType'] ?? '').toString().trim();
    final caseTypeRaw = (caseData['caseTypeRaw'] ?? '').toString().trim();
    final headerTitle = [
      caseNumber,
      if (caseType.isNotEmpty) caseType,
    ].join(' • ');

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(caseData['courtName'] ?? 'Unknown court').toString()} • ${(caseData['cnr'] ?? '').toString()}',
                          style: const TextStyle(color: Color(0xff6b7280)),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(
                    (caseData['caseStatus'] ?? 'Unknown').toString(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildInfoTile('Next Hearing', caseData['nextHearingDate']),
                  _buildInfoTile('First Hearing', caseData['firstHearingDate']),
                  _buildInfoTile('Filing Date', caseData['filingDate']),
                  _buildInfoTile('Registration Date', caseData['registrationDate']),
                  _buildInfoTile('Decision Date', caseData['decisionDate']),
                  _buildInfoTile('Bench', caseData['benchName']),
                  _buildInfoTile('Case Type', caseData['caseType']),
                  _buildInfoTile('Case Type Raw', caseTypeRaw),
                  _buildInfoTile('Purpose', caseData['purpose']),
                  _buildInfoTile(
                    'Judicial Section',
                    caseData['judicialSectionRaw'] ?? caseData['judicialSection'],
                  ),
                  _buildInfoTile(
                    'Category',
                    caseData['caseCategoryFacetPath'],
                  ),
                  _buildInfoTile('CNR Court Code', caseData['cnrCourtCode']),
                  _buildInfoTile(
                    'Court Complex Code',
                    caseData['courtComplexCode'],
                  ),
                  _buildInfoTile('Court No', caseData['courtNo']),
                  _buildInfoTile('Filing No', caseData['filingNumber']),
                  _buildInfoTile(
                    'Registration No',
                    caseData['registrationNumber'],
                  ),
                  _buildInfoTile('Has Orders', caseData['hasOrders']),
                  _buildInfoTile('Has Judgments', caseData['hasJudgments']),
                  _buildInfoTile('Orders', caseData['orderCount']),
                  _buildInfoTile('Judgments', caseData['judgmentCount']),
                  _buildInfoTile('Hearings', caseData['hearingCount']),
                  _buildInfoTile('Interim Orders', caseData['interimOrderCount']),
                  _buildInfoTile('IA Count', caseData['iaCount']),
                ],
              ),
              const SizedBox(height: 18),
              _buildLabeledText('Petitioners', _joinList(caseData['petitioners'])),
              const SizedBox(height: 10),
              _buildLabeledText('Petitioner Advocates',
                  _joinList(caseData['petitionerAdvocates'])),
              const SizedBox(height: 10),
              _buildLabeledText('Respondents', _joinList(caseData['respondents'])),
              const SizedBox(height: 10),
              _buildLabeledText('Respondent Advocates',
                  _joinList(caseData['respondentAdvocates'])),
              const SizedBox(height: 10),
              _buildLabeledText('Judges', _joinList(caseData['judges'])),
              const SizedBox(height: 10),
              _buildLabeledText(
                'Acts & Sections',
                (caseData['actsAndSections'] ?? 'Not available').toString(),
              ),
              const SizedBox(height: 10),
              _buildLabeledText(
                'Location',
                '${(caseData['district'] ?? '').toString()} ${(caseData['state'] ?? '').toString()}'.trim(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Case Intelligence',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _buildLabeledText(
                'Summary',
                (caseAiAnalysis['caseSummary'] ?? 'Not available').toString(),
              ),
              const SizedBox(height: 10),
              _buildLabeledText(
                'Type',
                (caseAiAnalysis['caseType'] ?? 'Not available').toString(),
              ),
              const SizedBox(height: 10),
              _buildLabeledText(
                'Complexity',
                (caseAiAnalysis['complexity'] ?? 'Not available').toString(),
              ),
              const SizedBox(height: 10),
              _buildLabeledText(
                'Key Issues',
                _joinList(caseAiAnalysis['keyIssues']),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Entity Info',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildInfoTile('Entity CNR', entityInfo['cnr']),
                  _buildInfoTile('Created', entityInfo['dateCreated']),
                  _buildInfoTile('Modified', entityInfo['dateModified']),
                  _buildInfoTile(
                    'Next Date',
                    entityInfo['nextDateOfHearing'],
                  ),
                  _buildInfoTile('Request ID', detail['requestId']),
                ],
              ),
            ],
          ),
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Orders And Files',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                ...files.map(_buildFileCard),
              ],
            ),
          ),
        ],
        if (recommendedDocuments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xfffffbeb),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xfff59e0b)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xffb45309),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Suggested Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff78350f),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'These drafts are suggested from the case detail, purpose, issues, and litigation context.',
                  style: TextStyle(color: Color(0xff92400e), height: 1.5),
                ),
                const SizedBox(height: 14),
                ...recommendedDocuments.map(_buildRecommendedDocumentCard),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    final aiAnalysis = file['aiAnalysis'] is Map
        ? Map<String, dynamic>.from(file['aiAnalysis'])
        : <String, dynamic>{};
    final foundational = aiAnalysis['foundational_metadata'] is Map
        ? Map<String, dynamic>.from(aiAnalysis['foundational_metadata'])
        : <String, dynamic>{};
    final deepContext = aiAnalysis['deep_legal_substance_context'] is Map
        ? Map<String, dynamic>.from(aiAnalysis['deep_legal_substance_context'])
        : <String, dynamic>{};
    final insights = aiAnalysis['intelligent_insights_analytics'] is Map
        ? Map<String, dynamic>.from(aiAnalysis['intelligent_insights_analytics'])
        : <String, dynamic>{};
    final coreCaseIdentifiers =
        foundational['core_case_identifiers'] is Map
            ? Map<String, dynamic>.from(
                foundational['core_case_identifiers'],
              )
            : <String, dynamic>{};
    final proceduralDetails =
        foundational['procedural_details_from_order'] is Map
            ? Map<String, dynamic>.from(
                foundational['procedural_details_from_order'],
              )
            : <String, dynamic>{};
    final legalContent = deepContext['core_legal_content_analysis'] is Map
        ? Map<String, dynamic>.from(deepContext['core_legal_content_analysis'])
        : <String, dynamic>{};
    final reasoningAnalysis =
        deepContext['arguments_and_reasoning_analysis'] is Map
            ? Map<String, dynamic>.from(
                deepContext['arguments_and_reasoning_analysis'],
              )
            : <String, dynamic>{};
    final impactAssessment =
        insights['order_significance_and_impact_assessment'] is Map
            ? Map<String, dynamic>.from(
                insights['order_significance_and_impact_assessment'],
              )
            : <String, dynamic>{};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabeledText('PDF File', (file['pdfFile'] ?? 'Not available').toString()),
          const SizedBox(height: 8),
          _buildLabeledText(
            'Markdown File',
            (file['markdownFile'] ?? 'Not available').toString(),
          ),
          const SizedBox(height: 8),
          _buildLabeledText(
            'Markdown Content',
            (file['markdownContent'] ?? 'Not available').toString(),
          ),
          if (aiAnalysis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffdbeafe)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order AI Highlights',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff1e3a8a),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildInfoTile(
                        'Primary Case No',
                        coreCaseIdentifiers['case_number_primary'],
                      ),
                      _buildInfoTile(
                        'Order Case Type',
                        coreCaseIdentifiers['case_type'],
                      ),
                      _buildInfoTile(
                        'Bench Composition',
                        coreCaseIdentifiers['bench_composition'],
                      ),
                      _buildInfoTile(
                        'Order Date',
                        coreCaseIdentifiers['order_date'],
                      ),
                      _buildInfoTile(
                        'Order Nature',
                        proceduralDetails['order_nature'],
                      ),
                      _buildInfoTile(
                        'Disposition',
                        proceduralDetails['disposition_status_indicated'],
                      ),
                      _buildInfoTile(
                        'Outcome',
                        proceduralDetails['disposition_outcome_if_disposed'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLabeledText(
                    'Executive Summary',
                    (impactAssessment['ai_generated_executive_summary'] ?? '')
                        .toString(),
                  ),
                  const SizedBox(height: 10),
                  _buildLabeledText(
                    'Litigant Summary',
                    (impactAssessment[
                                'plain_language_summary_for_litigants_outcome_focused'] ??
                            '')
                        .toString(),
                  ),
                  const SizedBox(height: 10),
                  _buildLabeledText(
                    'Court Reasoning',
                    (reasoningAnalysis['court_reasoning_for_decision'] ?? '')
                        .toString(),
                  ),
                  const SizedBox(height: 10),
                  _buildLabeledText(
                    'Ratio Decidendi',
                    ((reasoningAnalysis['ratio_decidendi_extracted'] is Map
                                ? Map<String, dynamic>.from(
                                    reasoningAnalysis[
                                        'ratio_decidendi_extracted'],
                                  )
                                : <String, dynamic>{})['statement'] ??
                            '')
                        .toString(),
                  ),
                  const SizedBox(height: 10),
                  _buildLabeledText(
                    'Statutes Cited',
                    _joinList(
                      (legalContent['statutes_cited_and_applied'] is List)
                          ? (legalContent['statutes_cited_and_applied'] as List)
                              .map(
                                (item) => item is Map
                                    ? [
                                        (item['act_name'] ?? '').toString(),
                                        (item['section_article_rule'] ?? '')
                                            .toString(),
                                      ].where((part) => part.trim().isNotEmpty).join(' - ')
                                    : item.toString(),
                              )
                              .where((item) => item.trim().isNotEmpty)
                              .toList()
                          : <String>[],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLabeledText(
                    'Specific Directions',
                    _joinList(
                      proceduralDetails['specific_directions_given_by_court'],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListBlock(String label, dynamic value) {
    final items = value is List
        ? value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xff6b7280),
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xff111827),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xff111827),
        ),
      ),
    );
  }

  Map<String, String> _splitActsAndSections(String value) {
    final text = value.trim();
    if (text.isEmpty || text == 'Not available') {
      return <String, String>{
        'acts': 'Not available',
        'sections': 'Not available',
      };
    }

    if (text.contains(' - ')) {
      final parts = text.split(' - ');
      return <String, String>{
        'acts': parts.first.trim().isEmpty ? 'Not available' : parts.first.trim(),
        'sections': parts.skip(1).join(' - ').trim().isEmpty
            ? 'Not available'
            : parts.skip(1).join(' - ').trim(),
      };
    }

    return <String, String>{
      'acts': text,
      'sections': 'Not available',
    };
  }

  Widget _buildStructuredTable({required List<_StructuredRow> rows}) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.5),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.all(color: const Color(0xffd1d5db)),
      children: rows.map((row) {
        if (row.mode == _StructuredRowMode.full) {
          return TableRow(
            children: [
              _StructuredLabelCell(row.label1),
              _StructuredValueCell(row.value1, colSpan: false),
              const SizedBox.shrink(),
              const SizedBox.shrink(),
            ],
          );
        }
        if (row.mode == _StructuredRowMode.single) {
          return TableRow(
            children: [
              _StructuredLabelCell(row.label1),
              _StructuredValueCell(row.value1),
              const SizedBox.shrink(),
              const SizedBox.shrink(),
            ],
          );
        }
        return TableRow(
          children: [
            _StructuredLabelCell(row.label1),
            _StructuredValueCell(row.value1),
            _StructuredLabelCell(row.label2 ?? ''),
            _StructuredValueCell(row.value2 ?? ''),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPartySection({
    required List<String> parties,
    required List<String> advocates,
    bool repeatAdvocatesPerParty = false,
  }) {
    final displayParties = parties.isEmpty ? <String>['Not available'] : parties;
    final displayAdvocates = advocates.isEmpty ? <String>[] : advocates;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd1d5db)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: displayParties.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final party = entry.value;
          final advocateText = displayAdvocates.isEmpty
              ? null
              : repeatAdvocatesPerParty
                  ? displayAdvocates.join(', ')
                  : (entry.key < displayAdvocates.length
                      ? displayAdvocates[entry.key]
                      : displayAdvocates.join(', '));

          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == displayParties.length - 1 ? 0 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index) $party',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xff111827),
                  ),
                ),
                if (advocateText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Advocate - $advocateText',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xff111827),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHearingHistoryCard(List<Map<String, dynamic>> hearingHistory) {
    final rows = hearingHistory.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hearing History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xffc7df90)),
              ),
              child: Table(
                columnWidths: const <int, TableColumnWidth>{
                  0: FlexColumnWidth(2.4),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.5),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  const TableRow(
                    decoration: BoxDecoration(
                      color: Color(0xfff8fbef),
                    ),
                    children: [
                      _HistoryHeaderCell('Judge'),
                      _HistoryHeaderCell('Business on Date'),
                      _HistoryHeaderCell('Hearing Date'),
                      _HistoryHeaderCell('Purpose of Hearing'),
                    ],
                  ),
                  ...rows.asMap().entries.map(
                    (entry) => TableRow(
                      decoration: BoxDecoration(
                        color: entry.key.isEven
                            ? const Color(0xffdff0b6)
                            : const Color(0xffeef7d2),
                      ),
                      children: [
                        _HistoryValueCell(
                          _formatDisplayValue(entry.value['judge']),
                        ),
                        _HistoryValueCell(
                          _formatDisplayValue(entry.value['businessOnDate']),
                        ),
                        _HistoryValueCell(
                          _formatDisplayValue(entry.value['hearingDate']),
                        ),
                        _HistoryValueCell(
                          _formatDisplayValue(entry.value['purposeOfListing']),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedDocumentCard(Map<String, dynamic> item) {
    final reasons = item['reasons'] is List
        ? (item['reasons'] as List).map((reason) => reason.toString()).toList()
        : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xfffbbf24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (item['title'] ?? 'Suggested Document').toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff111827),
                  ),
                ),
              ),
              _buildConfidenceChip(
                (item['confidence'] ?? 'Medium').toString(),
              ),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5, right: 8),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: Color(0xff6b7280),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: Color(0xff374151),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabeledText(String label, String value) {
    final text = value.trim().isEmpty ? 'Not available' : value.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xff6b7280),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xff111827),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, dynamic value) {
    final text = _formatDisplayValue(value);
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xff6b7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xff111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    final normalized = label.trim().toLowerCase();
    final isPending = normalized == 'pending';
    final backgroundColor =
        isPending ? const Color(0xfffef3c7) : const Color(0xffdcfce7);
    final foregroundColor =
        isPending ? const Color(0xff92400e) : const Color(0xff166534);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildConfidenceChip(String label) {
    final normalized = label.trim().toLowerCase();
    Color backgroundColor;
    Color foregroundColor;

    if (normalized == 'high') {
      backgroundColor = const Color(0xffdcfce7);
      foregroundColor = const Color(0xff166534);
    } else if (normalized == 'low') {
      backgroundColor = const Color(0xfffee2e2);
      foregroundColor = const Color(0xff991b1b);
    } else {
      backgroundColor = const Color(0xffe0f2fe);
      foregroundColor = const Color(0xff075985);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final hasPrevious = _pagination['hasPreviousPage'] == true;
    final hasNext = _pagination['hasNextPage'] == true;

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: (!_isLoading && hasPrevious)
              ? () => _searchCases(page: _currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: (!_isLoading && hasNext)
              ? () => _searchCases(page: _currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 44, color: const Color(0xff9ca3af)),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xff6b7280),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shouldHideSearchCard =
        _caseDetail != null && _searchMode == _CaseSearchMode.cnr;

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Case Status',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Search eCourts by advocate or load a complete case detail directly from a CNR number.',
              style: TextStyle(color: Color(0xff6b7280)),
            ),
            if (!shouldHideSearchCard) ...[
              const SizedBox(height: 20),
              _buildSearchCard(),
              const SizedBox(height: 20),
            ] else
              const SizedBox(height: 20),
            Expanded(child: _buildResultsBody()),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeaderCell extends StatelessWidget {
  const _HistoryHeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xff1f2937),
        ),
      ),
    );
  }
}

enum _StructuredRowMode { pair, full, single }

class _StructuredRow {
  const _StructuredRow._(
    this.mode,
    this.label1,
    this.value1, {
    this.label2,
    this.value2,
  });

  final _StructuredRowMode mode;
  final String label1;
  final String value1;
  final String? label2;
  final String? value2;

  factory _StructuredRow.pair(
    String label1,
    String value1,
    String label2,
    String value2,
  ) {
    return _StructuredRow._(
      _StructuredRowMode.pair,
      label1,
      value1,
      label2: label2,
      value2: value2,
    );
  }

  factory _StructuredRow.full(String label1, String value1) {
    return _StructuredRow._(_StructuredRowMode.full, label1, value1);
  }

  factory _StructuredRow.single(String label1, String value1) {
    return _StructuredRow._(_StructuredRowMode.single, label1, value1);
  }
}

class _StructuredLabelCell extends StatelessWidget {
  const _StructuredLabelCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xff374151),
        ),
      ),
    );
  }
}

class _StructuredValueCell extends StatelessWidget {
  const _StructuredValueCell(this.text, {this.colSpan = true});

  final String text;
  final bool colSpan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xff111827),
        ),
      ),
    );
  }
}

class _HistoryValueCell extends StatelessWidget {
  const _HistoryValueCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.35,
          color: Color(0xff111827),
        ),
      ),
    );
  }
}
