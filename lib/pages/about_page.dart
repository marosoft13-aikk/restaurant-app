import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPageCinematic extends StatefulWidget {
  const AboutPageCinematic({super.key});

  @override
  State<AboutPageCinematic> createState() => _AboutPageCinematicState();
}

class _AboutPageCinematicState extends State<AboutPageCinematic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Alignment> _alignmentAnimation;

  static const String phoneNumber = '01026842005';

  @override
  void initState() {
    super.initState();

    // Animation for a slow-moving cinematic gradient
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _alignmentAnimation = AlignmentTween(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _callPhone() async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // fallback: show a dialog if cannot launch
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تعذر فتح تطبيق الهاتف'),
            content: Text('من فضلك اتصل: $phoneNumber'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // احتفظت بالنص كما زودتني به لكن قسمته لقطع لسهولة العرض
    const description = '''
MARO SOFT – شركة برمجة تطبيقات، تصميم، وتعليم برمجي احترافي
MARO SOFT هي شركة متخصصة في برمجة تطبيقات الموبايل، التصميم، والتعليم البرمجي، بنقدّم حلول تقنية متكاملة تجمع بين التنفيذ الاحترافي وبناء المبرمجين بشكل عملي حقيقي. هدفنا مش بس نطلع تطبيق شغال، لكن نطلع منتج قوي ومبرمج فاهم السوق.
نقوم بتصميم وتنفيذ تطبيقات موبايل بجودة عالية، مع إمكانية إضافة أي أفكار من قبل العميل، وتسليم لوحة تحكم كاملة، وتصميم الشكل والهيكل العام للتطبيق، مع متابعة مستمرة لحد ما التطبيق يشتغل بكفاءة ويتم رفعه رسميًا على Google Play.
''';

    const courseSection = '''
🔥 إعلان فتح الاشتراك في كورس برمجة تطبيقات الموبايل
📱 لو عندك شغف بالبرمجة وعايز تتعلم صح، الكورس ده معمول ليك. خلال 3 شهور فقط هتتعلم برمجة تطبيقات أندرويد حقيقية وتنفّذ تطبيق كامل من الصفر وترفعه على متجر Google Play، وبمبلغ رمزي جدًا.

💡 ماذا ستتعلم؟
Front End
Back End
تنفيذ تطبيق متكامل من البداية للنهاية
العمل على تطبيقات حجز مطاعم وكافيهات
إنشاء تطبيق لأي فكرة أو منصة

⚠️ ملاحظة: ده كورس برمجة تطبيقات موبايل مش مواقع إنترنت.
⚠️ ملاحظة مهمة: أغلب الكورسات بتكون مقتصرة على Front End أو Back End، إنما في MARO SOFT جمعنالك الاتنين مع بعض علشان تطلع مبرمج جاهز لسوق العمل.
''';

    const advantageSection = '''
🎯 مميزات الكورس ✔️ شرح أونلاين مبسط وواضح
✔️ اختبار بعد كل فيديو
✔️ اختيار الطلاب الأكفأ بناءً على نتائج الاختبارات
✔️ لو انت من بنها متاح متابعة أوفلاين كمان

👨‍💻 فرص عمل حقيقية – مش مجرد كورس الكورس مش تعليم وبس 👌
هيتم اختيار أفضل الطلاب من أولى ثانوي للعمل معنا في تطوير تطبيقات حقيقية لمدة سنتين (أولى + تانية ثانوي) بمقابل رمزي أثناء التدريب.
بعد السنتين يحصل المتدرب على شهادة معتمدة من MARO SOFT تثبت خبرة عملية فعلية لمدة سنتين.
🎓 وبعد تالتة ثانوي يتم اختيار الأكفأ للعمل معنا بمقابل مادي مجزي.
''';

    return Directionality(
      // Arabic layout (RTL)
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        // Transparent AppBar to allow background to show through
        appBar: AppBar(
          title: const Text('About MARO SOFT'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // Cinematic animated gradient background + subtle code-overlay
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: _alignmentAnimation.value,
                      radius: 1.2,
                      colors: [
                        Colors.deepOrange.shade900.withOpacity(0.95),
                        Colors.deepOrange.shade700.withOpacity(0.85),
                        Colors.indigo.shade900.withOpacity(0.6),
                        Colors.black87,
                      ],
                      stops: const [0.0, 0.25, 0.6, 1.0],
                    ),
                  ),
                );
              },
            ),

            // Subtle "code" texture overlay (repeating semi-transparent text)
            IgnorePointer(
              child: Opacity(
                opacity: 0.06,
                child: Center(
                  child: Transform.rotate(
                    angle: -0.3,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        30,
                        (_) => Text(
                          '<marosoft/>  const main() => runApp();',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main content with frosted-glass card
            SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                child: Column(
                  children: [
                    // Cinematic logo + title row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo with glow and elevation
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orangeAccent.withOpacity(0.35),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade200,
                                Colors.deepOrange.shade700
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/marosoft.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    'MARO\nSOFT',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MARO SOFT',
                                style: TextStyle(
                                  color: Colors.orange[50],
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.6),
                                      offset: const Offset(0, 1),
                                      blurRadius: 6,
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'برمجة ▪️ تصميم ▪️ تعليم عملي',
                                style: TextStyle(
                                  color: Colors.orange[100]!.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Frosted glass container for the main description
                    _FrostedGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // head cinematic accent
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.shade400,
                                      Colors.deepOrange.shade700
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'من نحن',
                                style: TextStyle(
                                  color: Colors.orange[50],
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.orange[50]!.withOpacity(0.95),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Course highlight card inside
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.14),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  '🔥 إعلان فتح الاشتراك في كورس برمجة تطبيقات الموبايل',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'خلال 3 شهور هتتعلم برمجة تطبيقات أندرويد حقيقية وتنفيذ تطبيق كامل، رفعه على Google Play، ومهارات Back & Front.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            courseSection,
                            style: TextStyle(
                              color: Colors.orange[50]!.withOpacity(0.95),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            advantageSection,
                            style: TextStyle(
                              color: Colors.orange[50]!.withOpacity(0.95),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Action buttons row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _callPhone,
                                  icon: const Icon(Icons.phone),
                                  label: const Text('اتصل الآن'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orangeAccent,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  // مثال: يمكن فتح صفحة تواصل أو نموذج تسجيل
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('للتواصل'),
                                      content: const Text(
                                          'للتسجيل أو الاستفسار أرسل رسالة على ��لرقم: 01026842005'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('حسناً'),
                                        )
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.message_outlined),
                                label: const Text('أرسل استفسار'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange[50],
                                  side: BorderSide(
                                    color: Colors.orange.withOpacity(0.24),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Small footer / cinematic credits
                    Text(
                      'MARO SOFT • برمجة ▪️ تصميم ▪️ تعليم عملي',
                      style: TextStyle(
                        color: Colors.orange[100]!.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted glass card used by the cinematic AboutPage
class _FrostedGlassCard extends StatelessWidget {
  final Widget child;
  const _FrostedGlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        // blur the background behind the card
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
