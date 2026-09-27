import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart' as models;
import '../domain/enums.dart' as enums;
import '../domain/holiday.dart';
import '../core/deadline_calculator.dart';
import '../data/holidays_repository.dart';
import '../data/history_repository.dart';

// Providers
final holidaysRepoProvider = Provider((ref) => HolidaysRepository());
final historyRepoProvider = Provider((ref) => HistoryRepository());

final currentYearHolidaysProvider = FutureProvider<List<Holiday>>((ref) async {
  final repo = ref.watch(holidaysRepoProvider);
  return repo.getHolidays(DateTime.now().year);
});

final historyProvider = NotifierProvider<HistoryNotifier, List<models.CalculationRecord>>(HistoryNotifier.new);

class HistoryNotifier extends Notifier<List<models.CalculationRecord>> {
  @override
  List<models.CalculationRecord> build() {
    _loadHistory();
    return [];
  }

  Future<void> _loadHistory() async {
    final repo = ref.read(historyRepoProvider);
    final history = await repo.getHistory();
    state = history;
  }

  Future<void> addRecord(models.CalculationRecord record) async {
    final repo = ref.read(historyRepoProvider);
    await repo.saveRecord(record);
    state = [record, ...state];
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  enums.Materia? _selectedMateria;
  enums.TipoActuacion? _selectedActuacion;
  DateTime? _fechaNotificacion;
  
  final TextEditingController _plazoController = TextEditingController();
  final TextEditingController _emplazamientoController = TextEditingController(text: '0');
  final TextEditingController _rolRucController = TextEditingController();
  final TextEditingController _tribunalController = TextEditingController();
  
  DateTime? _fechaVencimiento;

  @override
  void dispose() {
    _plazoController.dispose();
    _emplazamientoController.dispose();
    _rolRucController.dispose();
    _tribunalController.dispose();
    super.dispose();
  }

  enums.TipoComputo _obtenerTipoComputo(enums.Materia? materia) {
    if (materia == enums.Materia.penal) return enums.TipoComputo.corridos;
    if (materia == enums.Materia.tributario || materia == enums.Materia.sii || materia == enums.Materia.tgr) {
      return enums.TipoComputo.administrativo;
    }
    return enums.TipoComputo.judicial; 
  }

  void _calcularPlazo(List<Holiday> feriados) {
    if (_fechaNotificacion == null || _plazoController.text.isEmpty || _selectedMateria == null) return;
    
    final int dias = int.tryParse(_plazoController.text) ?? 0;
    final int diasEmplazamiento = int.tryParse(_emplazamientoController.text) ?? 0;
    final tipoComputo = _obtenerTipoComputo(_selectedMateria);
    
    final resultado = DeadlineCalculator.calculateDeadline(
      startDate: _fechaNotificacion!,
      days: dias,
      additionalDays: _selectedMateria == enums.Materia.civil ? diasEmplazamiento : 0,
      type: tipoComputo,
      holidays: feriados,
    );

    setState(() {
      _fechaVencimiento = resultado;
    });

    if (_selectedActuacion != null) {
       final record = models.CalculationRecord(
         id: const Uuid().v4(),
         title: _selectedActuacion!.informacion.nombre,
         startDate: _fechaNotificacion!,
         endDate: resultado,
         baseDays: dias,
         additionalDays: diasEmplazamiento,
         materia: _selectedMateria!,
         rolRuc: _rolRucController.text,
         tribunal: _tribunalController.text,
         tipoActuacion: _selectedActuacion,
       );
       ref.read(historyProvider.notifier).addRecord(record);
    }
  }

  @override
  Widget build(BuildContext context) {
    final holidaysAsyncValue = ref.watch(currentYearHolidaysProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'PLAZOS PROCESALES CHILE [TRON AAA]',
          style: TextStyle(
            color: Color(0xFF00FF41),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Row(
        children: [
          // Main Calculator Area
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_fechaVencimiento != null) _buildResultCard(),
                      if (_fechaVencimiento != null) const SizedBox(height: 24),
                      _buildForm(holidaysAsyncValue),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // History Sidebar (Tron style)
          Container(
            width: 340,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              border: Border(left: BorderSide(color: const Color(0xFF00FF41).withOpacity(0.3))),
            ),
            child: _buildHistoryPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final formatter = DateFormat("EEEE d 'de' MMMM 'de' yyyy, HH:mm 'hrs'", 'es');
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00FF41), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF41).withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            '⚡ FECHA VENCIMIENTO CALCULADA ⚡',
            style: TextStyle(
              color: Color(0xFFFF9900),
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            formatter.format(_fechaVencimiento!),
            style: const TextStyle(
              color: Color(0xFF00FF41),
              fontWeight: FontWeight.bold,
              fontSize: 26,
              shadows: [Shadow(color: Color(0xFF00FF41), blurRadius: 10)],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildNeonChip('Materia: ${_selectedMateria?.name.toUpperCase() ?? ''}'),
              _buildNeonChip('Actuación: ${_selectedActuacion?.informacion.nombre ?? ''}'),
              _buildNeonChip('Plazo: ${_plazoController.text} días'),
              if (_rolRucController.text.isNotEmpty)
                _buildNeonChip('Rol/RUC: ${_rolRucController.text}', color: const Color(0xFFFF9900)),
              if (_tribunalController.text.isNotEmpty)
                _buildNeonChip('Tribunal: ${_tribunalController.text}', color: const Color(0xFFFF9900)),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00FF41)),
              foregroundColor: const Color(0xFF00FF41),
            ),
            icon: const Icon(Icons.copy),
            label: const Text('Copiar Resultado Oficial'),
            onPressed: () {
              final text = "Vencimiento: ${formatter.format(_fechaVencimiento!)} | Rol: ${_rolRucController.text} | Tribunal: ${_tribunalController.text}";
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Resultado copiado con éxito!'),
                  backgroundColor: Color(0xFF121212),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNeonChip(String label, {Color color = const Color(0xFF00FF41)}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildForm(AsyncValue<List<Holiday>> holidaysAsyncValue) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9900).withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PARÁMETROS DE CÁUSTICA Y PLAZO',
            style: TextStyle(
              color: Color(0xFF00FF41),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<enums.Materia>(
            decoration: const InputDecoration(
              labelText: 'Materia / Submateria (Civil, Penal, Tributario, Aduanas, Constitucional, etc.)',
              prefixIcon: Icon(Icons.gavel, color: Color(0xFF00FF41)),
            ),
            dropdownColor: const Color(0xFF1A1A1A),
            value: _selectedMateria,
            items: enums.Materia.values.map((m) => DropdownMenuItem(
              value: m,
              child: Text(m.name.toUpperCase(), style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: (val) => setState(() => _selectedMateria = val),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<enums.TipoActuacion>(
            decoration: const InputDecoration(
              labelText: 'Tipo de Actuación y Fundamento Legal',
              prefixIcon: Icon(Icons.list_alt, color: Color(0xFF00FF41)),
            ),
            dropdownColor: const Color(0xFF1A1A1A),
            isExpanded: true,
            value: _selectedActuacion,
            items: enums.TipoActuacion.values.map((a) => DropdownMenuItem(
              value: a,
              child: Text(
                '${a.informacion.nombre.toUpperCase()} [${a.informacion.codigo} ${a.informacion.articulo}]',
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            )).toList(),
            onChanged: (val) {
              setState(() {
                _selectedActuacion = val;
                if (val != null) {
                  // Sugerir o rellenar plazo si se desea, o dejar libre
                }
              });
            },
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              TextFormField(
                controller: _rolRucController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Rol / RUC',
                  prefixIcon: Icon(Icons.badge, color: Color(0xFFFF9900)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tribunalController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Tribunal',
                  prefixIcon: Icon(Icons.account_balance_outlined, color: Color(0xFFFF9900)),
                ),
              ),
            ],
          ),
          if (_selectedActuacion != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00FF41)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fundamento Legal: ${_selectedActuacion!.informacion.codigo} - ${_selectedActuacion!.informacion.articulo}',
                    style: const TextStyle(color: Color(0xFF00FF41), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Plazo estándar: ${_selectedActuacion!.informacion.plazoDescripcion}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Column(
            children: [
              TextField(
                controller: _fechaNotificacion == null ? null : TextEditingController(),
                readOnly: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Fecha de Notificación / Inicio',
                  prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF00FF41)),
                  hintText: _fechaNotificacion != null 
                    ? DateFormat('dd-MM-yyyy').format(_fechaNotificacion!)
                    : 'Seleccione fecha...',
                  hintStyle: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _fechaNotificacion = date);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plazoController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Plazo Legal (días)',
                  prefixIcon: Icon(Icons.timer, color: Color(0xFF00FF41)),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          if (_selectedMateria == enums.Materia.civil) ...[
            const SizedBox(height: 20),
            TextFormField(
              controller: _emplazamientoController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Aumento Tabla Emplazamiento (días adicionales)',
                prefixIcon: Icon(Icons.add_road, color: Color(0xFF00FF41)),
                helperText: 'Aplica según tabla de emplazamiento CPC',
                helperStyle: TextStyle(color: Colors.white60),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 32),
          holidaysAsyncValue.when(
            data: (feriados) => SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calculate, color: Colors.black),
                label: const Text(
                  'CALCULAR PLAZO PROCESAL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.black),
                ),
                onPressed: () => _calcularPlazo(feriados),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF41),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                  shadowColor: const Color(0xFF00FF41),
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF41))),
            error: (err, stack) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                'Nota: Feriados offline activos (Error red: $err)',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel() {
    final history = ref.watch(historyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          color: Colors.black,
          child: Row(
            children: const [
              Icon(Icons.history, color: Color(0xFF00FF41), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'HISTORIAL DE CAUSAS',
                  style: TextStyle(
                    color: Color(0xFF00FF41),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF00FF41), height: 1),
        Expanded(
          child: history.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No hay cálculos recientes en el historial.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final record = history[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ListTile(
                        title: Text(
                          record.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (record.rolRuc != null && record.rolRuc!.isNotEmpty)
                              Text('Rol/RUC: ${record.rolRuc}', style: const TextStyle(color: Color(0xFFFF9900), fontSize: 11)),
                            if (record.tribunal != null && record.tribunal!.isNotEmpty)
                              Text('Tribunal: ${record.tribunal}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(
                              'Vence: ${DateFormat('dd-MM-yyyy').format(record.endDate)}',
                              style: const TextStyle(color: Color(0xFF00FF41), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
