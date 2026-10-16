

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <pthread.h>
#import <math.h>
#import <signal.h>
#import <unistd.h>
#import <string.h>
#import <stdlib.h>

// ============================================
// INTERFACE DECLARE TRUOC
// ============================================
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@interface ZMainVC : UIViewController
@end

// ============================================
// PID + BASE
// ============================================
extern int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize);
extern int proc_pidpath(int pid, void *buffer, uint32_t buffersize);

static int find_pid(const char *name) {
    int n = proc_listpids(1, 0, NULL, 0);
    if (n <= 0) return 0;
    pid_t *pids = (pid_t *)malloc(n * sizeof(pid_t));
    proc_listpids(1, 0, pids, n * sizeof(pid_t));
    char path[4096];
    int found = 0;
    for (int i = 0; i < n / (int)sizeof(pid_t); i++) {
        if (pids[i] == 0) continue;
        memset(path, 0, sizeof(path));
        proc_pidpath(pids[i], path, sizeof(path));
        if (strstr(path, name)) { found = pids[i]; break; }
    }
    free(pids);
    return found;
}

static int g_pid = 0;
static uintptr_t g_base = 0;
static task_t g_task = 0;

static BOOL attach_task(void) {
    g_pid = find_pid("freefiremax");
    if (g_pid <= 0) return NO;
    if (task_for_pid(mach_task_self(), g_pid, &g_task) != KERN_SUCCESS) return NO;
    struct task_dyld_info info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    if (task_info(g_task, TASK_DYLD_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return NO;
    g_base = info.all_image_info_addr;
    return g_base > 0;
}

static BOOL rd(uintptr_t addr, void *buf, size_t size) {
    if (!g_task || !addr) return NO;
    vm_size_t out;
    return vm_read_overwrite(g_task, addr, size, (vm_address_t)buf, &out) == KERN_SUCCESS;
}
static BOOL wr(uintptr_t addr, void *buf, size_t size) {
    if (!g_task || !addr) return NO;
    return vm_write(g_task, addr, (vm_address_t)buf, (mach_msg_type_number_t)size) == KERN_SUCCESS;
}
static float rd_f(uintptr_t a) { float v = 0; rd(a, &v, 4); return v; }
static int   rd_i(uintptr_t a) { int v = 0;   rd(a, &v, 4); return v; }
static BOOL  rd_b(uintptr_t a) { BOOL v = 0;  rd(a, &v, 1); return v; }
static void  wr_f(uintptr_t a, float v) { wr(a, &v, 4); }
static void  wr_i(uintptr_t a, int v)   { wr(a, &v, 4); }
static void  wr_b(uintptr_t a, uint8_t v) { wr(a, &v, 1); }

// ============================================
// OFFSET
// ============================================
#define OFF_PLAYER_LIST  0x7C4E1C
#define OFF_LOCAL        0x7C4E20
#define OFF_SIZE         0x1B0
#define OFF_POS          0x48
#define OFF_ROT          0x54
#define OFF_HEAD         0x88
#define OFF_HP           0xA0
#define OFF_VIS          0xA8
#define OFF_KN           0xAC
#define OFF_SPEED        0x2A4
#define OFF_WALL         0x3B8

typedef struct { float x, y, z; } Vec3;
static Vec3 rd_v3(uintptr_t a) {
    Vec3 v;
    v.x = rd_f(a);
    v.y = rd_f(a + 4);
    v.z = rd_f(a + 8);
    return v;
}

// ============================================
// CONFIG
// ============================================
static volatile BOOL CFG_aimbot     = NO;
static volatile BOOL CFG_headLock   = YES;
static volatile BOOL CFG_antiBan    = YES;
static volatile BOOL CFG_antiReport = YES;
static volatile BOOL CFG_antiAFK    = YES;
static volatile BOOL CFG_antiKick   = YES;
static volatile BOOL CFG_speed      = NO;
static volatile BOOL CFG_wallhack   = NO;
static volatile float CFG_fov       = 180.0f;
static volatile float CFG_smooth    = 0.30f;
static volatile float CFG_range     = 450.0f;

// ============================================
// ANTIBAN
// ============================================
static void antiReport(void) {
    wr_i(g_base + 0x8C2F10, 0);
    wr_i(g_base + 0x8C2F14, 0);
    wr_b(g_base + 0x8C2F20, 0x00);
}
static void antiAFK(void) {
    uintptr_t lp = 0;
    rd(g_base + OFF_LOCAL, &lp, 8);
    if (!lp) return;
    wr_f(lp + 0x2B8, 0.01f);
    wr_f(lp + 0x2BC, 0.01f);
}
static void antiKick(void) {
    wr_b(g_base + 0x8C3010, 0x00);
    wr_b(g_base + 0x8C3011, 0x00);
    wr_b(g_base + 0x8C3012, 0x00);
}
static void antiDetection(void) {
    wr_i(g_base + 0x8C4020, 0);
    wr_b(g_base + 0x8C4028, 0x01);
}
static void runAntiban(void) {
    if (CFG_antiReport) antiReport();
    if (CFG_antiAFK)    antiAFK();
    if (CFG_antiKick)   antiKick();
    antiDetection();
}

// ============================================
// AIMBOT
// ============================================
static float normAng(float a) {
    while (a > 180.0f) a -= 360.0f;
    while (a < -180.0f) a += 360.0f;
    return a;
}
static float lerpAng(float c, float t, float s) {
    return normAng(c + normAng(t - c) * s);
}
static float dist3(Vec3 a, Vec3 b) {
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    float dz = a.z - b.z;
    return sqrtf(dx*dx + dy*dy + dz*dz);
}
static void calcToHead(Vec3 l, Vec3 h, float *p, float *y) {
    float dx = h.x - l.x;
    float dy = h.y - l.y;
    float dz = h.z - l.z;
    float d  = sqrtf(dx*dx + dy*dy);
    *p = normAng(atan2f(dz, d) * 180.0f / (float)M_PI);
    *y = normAng(atan2f(dy, dx) * 180.0f / (float)M_PI);
}

static void runAimbot(void) {
    uintptr_t lp = 0;
    rd(g_base + OFF_LOCAL, &lp, 8);
    if (!lp) return;

    Vec3 lpos = rd_v3(lp + OFF_POS);
    uintptr_t lrotA = lp + OFF_ROT;
    Vec3 lrot = rd_v3(lrotA);

    uintptr_t pl = 0;
    rd(g_base + OFF_PLAYER_LIST, &pl, 8);
    int n = rd_i(g_base + OFF_PLAYER_LIST + 4);

    Vec3 bHead;
    float bScore = 999999.0f;
    BOOL found = NO;

    for (int i = 0; i < n; i++) {
        uintptr_t e = pl + i * OFF_SIZE;
        if (e == lp) continue;
        if (rd_i(e + OFF_HP) <= 0) continue;
        if (!rd_b(e + OFF_VIS)) continue;
        if (rd_b(e + OFF_KN)) continue;

        Vec3 pp = rd_v3(e + OFF_POS);
        Vec3 hd = rd_v3(e + OFF_HEAD);

        float d = dist3(lpos, pp);
        if (d > CFG_range) continue;

        float tp, ty;
        calcToHead(lpos, hd, &tp, &ty);
        float diff = fabsf(normAng(ty - lrot.y));
        if (diff > CFG_fov) continue;

        float s = diff * 1.5f + d * 0.5f;
        if (s < bScore) {
            bScore = s;
            bHead = hd;
            found = YES;
        }
    }

    if (found) {
        float tp, ty;
        calcToHead(lpos, bHead, &tp, &ty);
        wr_f(lrotA,     lerpAng(lrot.x, tp, CFG_smooth));
        wr_f(lrotA + 4, lerpAng(lrot.y, ty, CFG_smooth));
    }
}

static void runSpeed(void) {
    uintptr_t lp = 0;
    rd(g_base + OFF_LOCAL, &lp, 8);
    if (lp) wr_f(lp + OFF_SPEED, 8.5f);
}
static void runWall(void) {
    wr_b(g_base + OFF_WALL, 0x01);
}

// ============================================
// THREAD INJECT
// ============================================
static void *inject_thread(void *arg) {
    (void)arg;
    while (1) {
        if (!g_task || !g_base) {
            attach_task();
            usleep(500000);
            continue;
        }
        if (kill(g_pid, 0) != 0) {
            g_task = 0;
            g_base = 0;
            g_pid  = 0;
            usleep(500000);
            continue;
        }
        if (CFG_antiBan)  runAntiban();
        if (CFG_aimbot)   runAimbot();
        if (CFG_speed)    runSpeed();
        if (CFG_wallhack) runWall();
        usleep(8000);
    }
    return NULL;
}

// ============================================
// APP DELEGATE
// ============================================
@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    self.window.rootViewController = [[ZMainVC alloc] init];
    self.window.backgroundColor = [UIColor blackColor];
    [self.window makeKeyAndVisible];

    pthread_t t;
    pthread_create(&t, NULL, inject_thread, NULL);
    return YES;
}
@end

// ============================================
// MAIN VIEW CONTROLLER - MENU THUONG
// ============================================
@implementation ZMainVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.09 alpha:1.0];
    [self buildUI];
}

- (void)buildUI {
    CGFloat W = self.view.bounds.size.width;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, W, 32)];
    title.text = @"Zwilz HLong";
    title.textAlignment = NSTextAlignmentCenter;
    title.textColor = [UIColor colorWithRed:0 green:0.9 blue:1 alpha:1];
    title.font = [UIFont boldSystemFontOfSize:26];
    [self.view addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(0, 116, W, 20)];
    sub.text = @"Free Fire MAX Injector";
    sub.textAlignment = NSTextAlignmentCenter;
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    sub.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:sub];

    CGFloat y = 170;
    y = [self addToggleRow:@"Aimbot"       y:y tag:100 def:CFG_aimbot];
    y = [self addToggleRow:@"Head Lock"    y:y tag:101 def:CFG_headLock];
    y = [self addToggleRow:@"Anti Ban"     y:y tag:103 def:CFG_antiBan];
    y = [self addToggleRow:@"Anti Report"  y:y tag:104 def:CFG_antiReport];
    y = [self addToggleRow:@"Anti AFK"     y:y tag:105 def:CFG_antiAFK];
    y = [self addToggleRow:@"Anti Kick"    y:y tag:106 def:CFG_antiKick];
    y = [self addToggleRow:@"Speed"        y:y tag:107 def:CFG_speed];
    y = [self addToggleRow:@"Wallhack"     y:y tag:108 def:CFG_wallhack];

    UILabel *fl = [[UILabel alloc] initWithFrame:CGRectMake(24, y + 14, 120, 16)];
    fl.text = @"FOV";
    fl.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    fl.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:fl];

    UISlider *fs = [[UISlider alloc] initWithFrame:CGRectMake(24, y + 32, W - 48, 24)];
    fs.minimumValue = 30;
    fs.maximumValue = 360;
    fs.value = CFG_fov;
    fs.tintColor = [UIColor cyanColor];
    [fs addTarget:self action:@selector(onFov:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:fs];

    UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(24, y + 62, 120, 16)];
    sl.text = @"Smooth";
    sl.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    sl.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:sl];

    UISlider *ss = [[UISlider alloc] initWithFrame:CGRectMake(24, y + 80, W - 48, 24)];
    ss.minimumValue = 0.05;
    ss.maximumValue = 1.0;
    ss.value = CFG_smooth;
    ss.tintColor = [UIColor cyanColor];
    [ss addTarget:self action:@selector(onSmooth:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:ss];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(24, y + 130, W - 48, 52);
    [btn setTitle:@"INJECT NOW" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    btn.backgroundColor = [UIColor colorWithRed:0 green:0.7 blue:1 alpha:1];
    btn.layer.cornerRadius = 14;
    btn.layer.shadowColor = [UIColor cyanColor].CGColor;
    btn.layer.shadowOpacity = 0.7;
    btn.layer.shadowRadius = 12;
    [btn addTarget:self action:@selector(onInject) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 192, W, 18)];
    hint.text = @"Mo Free Fire MAX truoc, sau do nhan INJECT";
    hint.textAlignment = NSTextAlignmentCenter;
    hint.textColor = [UIColor colorWithWhite:1 alpha:0.4];
    hint.font = [UIFont systemFontOfSize:11];
    [self.view addSubview:hint];
}

- (CGFloat)addToggleRow:(NSString *)name y:(CGFloat)y tag:(NSInteger)tag def:(BOOL)def {
    CGFloat W = self.view.bounds.size.width;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, W - 32, 42)];
    row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    row.layer.cornerRadius = 12;

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(18, 0, 200, 42)];
    l.text = name;
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [row addSubview:l];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(W - 32 - 58, 5, 51, 31)];
    sw.onTintColor = [UIColor colorWithRed:0 green:0.9 blue:1 alpha:1];
    sw.tag = tag;
    sw.on = def;
    [sw addTarget:self action:@selector(onSw:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];

    [self.view addSubview:row];
    return y + 50;
}

- (void)onSw:(UISwitch *)s {
    switch (s.tag) {
        case 100: CFG_aimbot = s.on; break;
        case 101: CFG_headLock = s.on; break;
        case 103: CFG_antiBan = s.on; break;
        case 104: CFG_antiReport = s.on; break;
        case 105: CFG_antiAFK = s.on; break;
        case 106: CFG_antiKick = s.on; break;
        case 107: CFG_speed = s.on; break;
        case 108: CFG_wallhack = s.on; break;
        default: break;
    }
}

- (void)onFov:(UISlider *)s { CFG_fov = s.value; }
- (void)onSmooth:(UISlider *)s { CFG_smooth = s.value; }

- (void)onInject {
    g_task = 0;
    g_base = 0;
    g_pid  = 0;

    NSString *msg;
    if (attach_task()) {
        msg = [NSString stringWithFormat:@"Da inject vao Free Fire MAX (PID %d)", g_pid];
    } else {
        msg = @"Khong tim thay Free Fire MAX. Hay mo game truoc!";
    }

    UIAlertController *a = [UIAlertController
                            alertControllerWithTitle:@"Zwilz HLong"
                            message:msg
                            preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK"
                                          style:UIAlertActionStyleDefault
                                        handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

// ============================================
// MAIN
// ============================================
int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
