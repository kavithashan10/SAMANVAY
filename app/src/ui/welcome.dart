import 'package:flutter/material.dart';

import '../../lpu_demo_data.dart' show demoDepartments;
import '../../samanvay_design.dart';
import '../core/models.dart';
import 'brand.dart';
import 'common.dart';
import 'session.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final s = context.session;
    const steps = [
      ('01', 'Request', 'Draw where and when you need to dig. Every request gets a reference number.'),
      ('02', 'Check', 'Each department ticks its own checklist; the map flags pipes, cables and other planned works nearby.'),
      ('03', 'Dig once', 'Combine works on the same road, record the restoration, and close with evidence.'),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Row(children: [
              const Expanded(child: SvEyebrow('Infrastructure coordination')),
              const ThemeToggleButton(),
            ]),
            const Gap(28),
            const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 96)),
            const Gap(26),
            Text('Know below.\nDig above.', style: SvType.display(p.ink)),
            const Gap(16),
            Text('One shared map and one workflow for every department that digs the same road.',
                style: SvType.lead(p.inkSoft)),
            const Gap(32),
            SvPillButton(
              label: 'Sign in',
              kind: SvButtonKind.primary,
              expand: true,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
            ),
            const Gap(12),
            SvPillButton(
              label: 'Explore the LPU demonstration',
              icon: Icons.play_circle_outline,
              expand: true,
              onPressed: () => showDemoRolePicker(context),
            ),
            if (s.backendError != null) ...[
              const Gap(12),
              Text(s.backendError!, style: SvType.caption(p.muted)),
            ],
            const Gap(48),
            const SvEyebrow('How it works'),
            const Gap(8),
            Text('Three steps, every department', style: SvType.heading2(p.ink)),
            const Gap(16),
            for (final (n, title, body) in steps) ...[
              SvCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n, style: SvType.heading2(SvColors.gold).copyWith(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: SvType.title(p.ink).copyWith(fontSize: 17)),
                      const Gap(4),
                      Text(body, style: SvType.bodySm(p.inkSoft)),
                    ]),
                  ),
                ]),
              ),
              const Gap(12),
            ],
            const Gap(28),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: SvColors.inkBandSoft, borderRadius: BorderRadius.circular(SvRadius.lg)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SvEyebrow('Honest by design', color: SvColors.mute),
                const Gap(10),
                Text('A map is advice, not clearance.', style: SvType.heading2(SvColors.canvas)),
                const Gap(10),
                Text(
                  'Every record says where it came from and how sure we are. Empty map areas mean “no data”, never “nothing buried”. '
                  'Field verification and the owning department’s clearance always come first.',
                  style: SvType.bodySm(SvColors.mute),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showDemoRolePicker(BuildContext context) {
  final session = context.session;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      var dept = 'power';
      return StatefulBuilder(builder: (sheet, setSheet) {
        final p = SvPalette.of(sheet);
        void go(AppRole role) {
          Navigator.of(sheet).pop();
          session.enterDemo(role, departmentId: dept);
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SvEyebrow('LPU Phagwara · demonstration'),
              const Gap(6),
              Text('Step in as…', style: SvType.heading2(p.ink)),
              const Gap(6),
              Text('Offline sample data for the five-minute walkthrough. You can switch role any time from the gold strip.',
                  style: SvType.bodySm(p.inkSoft)),
              const Gap(18),
              for (final role in AppRole.values) ...[
                SvCard(
                  onTap: () => go(role),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(children: [
                    Icon(role.icon, color: p.inkSoft),
                    const SizedBox(width: 14),
                    Expanded(child: Text(role.label, style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600))),
                    Icon(Icons.arrow_forward, color: p.muted, size: 18),
                  ]),
                ),
                if (role == AppRole.department) ...[
                  const Gap(8),
                  SvPillTabs<String>(
                    options: [for (final d in demoDepartments) (d.id, d.short)],
                    selected: dept,
                    onChanged: (v) => setSheet(() => dept = v),
                  ),
                ],
                const Gap(8),
              ],
            ]),
          ),
        );
      });
    },
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;
  String? _info;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final s = context.session;
    if (_register) {
      final (ok, msg) = await s.signUp(_name.text, _email.text, _password.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        ok ? _info = msg : _error = msg;
        if (ok && s.repo == null) _register = false;
      });
    } else {
      final err = await s.signIn(_email.text, _password.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err;
      });
    }
    if (mounted && s.repo != null) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 40), children: [
          const BrandMark(size: 56),
          const Gap(20),
          Text(_register ? 'Create your\naccount' : 'Welcome\nback', style: SvType.heading1(p.ink)),
          const Gap(8),
          Text(
            _register ? 'Citizens can request works and report problems. Officials get their role from an administrator.' : 'Sign in with your SAMANVAY email and password.',
            style: SvType.bodySm(p.inkSoft),
          ),
          const Gap(24),
          SvPillTabs<bool>(
            options: const [(false, 'Sign in'), (true, 'Create account')],
            selected: _register,
            onChanged: (v) => setState(() {
              _register = v;
              _error = null;
              _info = null;
            }),
          ),
          const Gap(20),
          if (_register) ...[
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
            ),
            const Gap(12),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email address',
          ),
          const Gap(12),
          TextFormField(
            controller: _password,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hide = !_hide)),
            ),
            validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const Gap(14),
            SvCard(color: const Color(0xFFFBEAE6), borderColor: const Color(0xFFE7B8AC), padding: const EdgeInsets.all(14), child: Text(_error!, style: SvType.bodySm(const Color(0xFF8A2E1F)))),
          ],
          if (_info != null) ...[
            const Gap(14),
            SvCard(color: const Color(0xFFE8EFE4), borderColor: const Color(0xFFB9CDB0), padding: const EdgeInsets.all(14), child: Text(_info!, style: SvType.bodySm(SvColors.forest))),
          ],
          const Gap(22),
          SvPillButton(
            label: _busy ? 'Please wait…' : (_register ? 'Create account' : 'Sign in'),
            kind: SvButtonKind.primary,
            expand: true,
            onPressed: _busy ? null : _submit,
          ),
          if (!_register) ...[
            const Gap(8),
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final msg = await context.session.resendConfirmation(_email.text);
                        if (mounted) setState(() => _info = msg);
                      },
                child: const Text('Resend confirmation email'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
