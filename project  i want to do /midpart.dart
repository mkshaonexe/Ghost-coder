        backgroundColor: const Color(0xFFF3F5F5),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, selectedItemColor: Colors.black, unselectedItemColor: Colors.grey, showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Transfer'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [

              // ── SECTION 1: Header ──────────────────────────────
              const Text('Good morning, Terry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Text('Welcome to Neobank', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),

              // ── SECTION 2: Balance Card ────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Your balance', style: TextStyle(color: Colors.black54)),
                  const Text('\$3,200.00', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size.fromHeight(50)),
                    onPressed: () {},
                    child: const Text('Add money', style: TextStyle(color: Colors.white)),
                  ),
                ]),
              ),
              const SizedBox(height: 32),

              // ── SECTION 3: Cards Slider (Self-contained, no helpers needed) ──
              const Text('Your cards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: PageView(
                  controller: PageController(viewportFraction: 0.85),
                  children: [
                    // Card 1 (Debit)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFFC9F158), borderRadius: BorderRadius.circular(24)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('N.', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900)),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Debit', style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 12)),
                          const Text('•••• 4568', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                        ]),
                      ]),
                    ),
                    // Card 2 (Credit)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('N.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Credit', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                          const Text('•••• 2478', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ]),
                      ]),
                    ),
                    // Card 3 (Bank)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFFE2E4E8), borderRadius: BorderRadius.circular(24)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('N.', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900)),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Bank', style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 12)),
                          const Text('•••• 9012', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                        ]),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── SECTION 4: Transactions (Self-contained, no helpers needed) ──
              const Text('Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              // Transaction 1: Starbucks
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.local_cafe)),
                  const SizedBox(width: 16),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Starbucks Coffee', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Oct 17, 09:00 PM', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                  const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('-\$44.80', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('+\$1.65', style: TextStyle(color: Color(0xFF7CA018), fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                ]),
              ),

              // Transaction 2: Direct Deposit
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.account_balance_wallet)),
                  const SizedBox(width: 16),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Direct Deposit', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Oct 15, 08:30 AM', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                  const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('+\$1,500.00', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ]),
              ),

              // Transaction 3: Apple Store
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.laptop_mac)),
                  const SizedBox(width: 16),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Apple Store', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Oct 12, 02:15 PM', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                  const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('-\$999.00', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ]),
              ),

              // Transaction 4: McDonald's
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.fastfood)),
                  const SizedBox(width: 16),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('McDonald\'s', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Oct 10, 01:20 PM', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                  const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('-\$12.50', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('+\$0.50', style: TextStyle(color: Color(0xFF7CA018), fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                ]),
              ),

              // Transaction 5: Nike Store
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.shopping_bag)),
                  const SizedBox(width: 16),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Nike Store', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Oct 08, 04:45 PM', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                  const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('-\$120.00', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ]),
              ),

              // Transaction 6: Netflix
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.movie)),
                  const SizedBox(width: 16),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Netflix', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Oct 05, 10:00 AM', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                  const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('-\$15.99', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ]),
              ),

            ],
          ),
        ),
      );