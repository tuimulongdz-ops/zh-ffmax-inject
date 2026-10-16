


#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <pthread.h>
#import <math.h>
#import <signal.h>

// ============================================
// DECLARE TRUOC TAT CA INTERFACE
// ============================================
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIWindow *menuWindow;
@end

@interface ZFloatingMenuVC : UIViewController
@end

// ============================================
// TIM PID + BASE
// ============================================
extern int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize);
extern int proc_pidpath(int pid, void *buffer, uint32_t buffersize);

static int find_pid(const char *name) {
    int n = proc_listpids(1, 0, NULL, 0);
    if (n <= 0) return 0;
    pid_t *pids = malloc(n * sizeof(pid_t));
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

// ============================================
// DOC / GHI BO NHO
// ============================================
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
static Vec3 rd_v3(uintptr_t a) { Vec3 v; v.x = rd_f(a); v.y = rd_f(a+4); v.z = rd_f(a+8); return v; }

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
    uintptr_t lp = 0; rd(g_base + OFF_LOCAL, &lp, 8);
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
static float normAng(float a){ while(a>180)a-=360; while(a<-180)a+=360; return a; }
static float lerpAng(float c,float t,float s){ return normAng(c + normAng(t-c)*s); }
static float dist3(Vec3 a,Vec3 b){ float dx=a.x-b.x,dy=a.y-b.y,dz=a.z-b.z; return sqrtf(dx*dx+dy*dy+dz*dz); }
static void calcToHead(Vec3 l,Vec3 h,float*p,float*y){
    float dx=h.x-l.x, dy=h.y-l.y, dz=h.z-l.z;
    float d = sqrtf(dx*dx+dy*dy);
    *p = normAng(atan2f(dz,d)*180.0f/M_PI);
    *y = normAng(atan2f(dy,dx)*180.0f/M_PI);
}

static void runAimbot(void) {
    uintptr_t lp = 0; rd(g_base + OFF_LOCAL, &lp, 8);
    if (!lp) return;
    Vec3 lpos = rd_v3(lp + OFF_POS);
    uintptr_t lrotA = lp + OFF_ROT;
    Vec3 lrot = rd_v3(lrotA);

    uintptr_t pl = 0; rd(g_base + OFF_PLAYER_LIST, &pl, 8);
    int n = rd_i(g_base + OFF_PLAYER_LIST + 4);

    Vec3 bHead; float bScore = 999999.f; BOOL f = NO;
    for (int i=0; i<n; i++) {
        uintptr_t e = pl + i*OFF_SIZE;
        if (e == lp) continue;
        if (rd_i(e+OFF_HP) <= 0) continue;
        if (!rd_b(e+OFF_VIS)) continue;
        if (rd_b(e+OFF_KN)) continue;
        Vec3 pp = rd_v3(e+OFF_POS);
        Vec3 hd = rd_v3(e+OFF_HEAD);
        float d = dist3(lpos, pp);
        if (d > CFG_range) continue;
        float tp, ty; calcToHead(lpos, hd, &tp, &ty);
        float diff = fabsf(normAng(ty - lrot.y));
        if (diff > CFG_fov) continue;
        float s = diff*1.5f + d*0.5f;
        if (s < bScore) { bScore = s; bHead = hd; f = YES; }
    }
    if (f) {
        float tp, ty; calcToHead(lpos, bHead, &tp, &ty);
        wr_f(lrotA,   lerpAng(lrot.x, tp, CFG_smooth));
        wr_f(lrotA+4, lerpAng(lrot.y, ty, CFG_smooth));
    }
}
static void runSpeed(void){ uintptr_t lp=0; rd(g_base+OFF_LOCAL,&lp,8); if(lp) wr_f(lp+OFF_SPEED, 8.5f); }
static void runWall(void){ wr_b(g_base+OFF_WALL, 0x01); }

// ============================================
// THREAD INJECT
// ============================================
static void *inject_thread(void *arg) {
    (void)arg;
    while (1) {
        if (!g_task || !   g_base) {
            attach_task();
            usleep( y500000);
            continue;
        }
        if = (kill(g_pid,  [0) != 0) {
            g_taskself = 0; g_base = 0 add; g_pid = 0;
            usleep(500000);
            continue;
        }
        if (CFG_antiBan) runAntiban();
        if (CFG_aimbot)  runAimbot();
        if (CFG_speed)   runSpeed();
        if (CFG_wallhack) runWall();
        usleep(8000);
    }
    return NULL;
}

// ============================================
// APP DELEGATE IMPLEMENTATION
// ============================================
@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application; (void)launchOptions;

    // Lay bounds tu UIScreen theo cach moi (khong dung mainScreen)
    CGRect bounds = CGRectMake(0, 0, 390, 844);
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene *)scene;
            bounds = ws.coordinateSpace.bounds;
            break;
        }
    }

    self.window = [[UIWindow alloc] initWithFrame:bounds];
    self.window.rootViewController = [UIViewController new];
    self.window.backgroundColor = [UIColor blackColor];
    [self.window makeKeyAndVisible];

    pthread_t t;
    pthread_create(&t, NULL, inject_thread, NULL);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self showFloatingMenu:bounds];
    });
    return YES;
}

- (void)showFloatingMenu:(CGRect)bounds {
    self.menuWindow = [[UIWindow alloc] initWithFrame:bounds];
    self.menuWindow.windowLevel = UIWindowLevelAlert + 100;
    self.menuWindow.backgroundColor = [UIColor clearColor];
    self.menuWindow.rootViewController = [[ZFloatingMenuVC alloc] init];
    self.menuWindow.hidden = NO;
}
@end

// ============================================
// FLOATING MENU IMPLEMENTATION
// ============================================
@implementation ZFloatingMenuVC {
    UIView *panel;
    UIButton *fab;
    BOOL expanded;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    expanded = YES;
    [self buildPanel];
    [self buildFab];
}

- (void)buildPanel {
    CGFloat w = 280, h = 560;
    panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, w, h)];
    panel.backgroundColor = [UIColor colorWithWhite:0.03 alpha:0.88];
    panel.layer.cornerRadius = 22;
    panel.layer.borderWidth = 1.5;
    panel.layer.borderColor = [UIColor colorWithRed:0 green:0.9 blue:1 alpha:1].CGColor;
    panel.layer.shadowColor = [UIColor cyanColor].CGColor;
    panel.layer.shadowOpacity = 0.7;
    panel.layer.shadowRadius = 18;
    panel.layer.shadowOffset = CGSizeZero;

    UIView *hdr = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 60)];
    hdr.backgroundColor = [UIColor clearColor];
    [panel addSubview:hdr];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, w-60, 24)];
    t.text = @"Zwilz HLong";
    t.textColor = [UIColor colorWithRed:0 green:0.9 blue:1 alpha:1];
    t.font = [UIFont boldSystemFontOfSize:18];
    [hdr addSubview:t];

    UILabel *s = [[UILabel alloc] initWithFrame:CGRectMake(16, 34, w-60, 16)];
    s.text = @"FF MAX Inject v1.0";
    s.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    s.font = [UIFont systemFontOfSize:10];
    [hdr addSubview:s];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w-50, 16, 34, 34);
    [close setTitle:@"—" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [close addTarget:self action:@selector(collapse) forControlEvents:UIControlEventTouchUpInside];
    [hdr addSubview:close];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                    initWithTarget:self action:@selector(onPan:)];
    [hdr addGestureRecognizer:pan];

    CGFloat y = 68;
    y = [self addToggle:@"Aimbot"       y:y tag:100 def:CFG_aimbot];
    y = [self addToggle:@"Head Lock"    y:y tag:101 def:CFG_headLock];
    y = [self addToggle:@"Anti Ban"     y:y tag:103 def:CFG_antiBan];
    y = [self addToggle:@"Anti Report"  y:y tag:104 def:CFG_antiReport];
Toggle:@"Anti AFK"     y:y tag:105 def:CFG_antiAFK];
    y = [self addToggle:@"Anti Kick"    y:y tag:106 def:CFG_antiKick];
    y = [self addToggle:@"Speed"        y:y tag:107 def:CFG_speed];
    y = [self addToggle:@"Wallhack"     y:y tag:108 def:CFG_wallhack];

    UILabel *fl = [[UILabel alloc] initWithFrame:CGRectMake(16, y+8, 100, 16)];
    fl.text = @"FOV";
    fl.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    fl.font = [UIFont systemFontOfSize:11];
    [panel addSubview:fl];

    UISlider *fs = [[UISlider alloc] initWithFrame:CGRectMake(16, y+26, w-32, 20)];
    fs.minimumValue = 30; fs.maximumValue = 360;
    fs.value = CFG_fov;
    fs.tintColor = [UIColor cyanColor];
    [fs addTarget:self action:@selector(onFov:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:fs];

    UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(16, y+54, 100, 16)];
    sl.text = @"Smooth";
    sl.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    sl.font = [UIFont systemFontOfSize:11];
    [panel addSubview:sl];

    UISlider *ss = [[UISlider alloc] initWithFrame:CGRectMake(16, y+72, w-32, 20)];
    ss.minimumValue = 0.05; ss.maximumValue = 1.0;
    ss.value = CFG_smooth;
    ss.tintColor = [UIColor cyanColor];
    [ss addTarget:self action:@selector(onSmooth:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:ss];

    [self.view addSubview:panel];
}

- (void)buildFab {
    fab = [UIButton buttonWithType:UIButtonTypeCustom];
    fab.frame = CGRectMake(20, 100, 56, 56);
    fab.layer.cornerRadius = 28;
    fab.backgroundColor = [UIColor colorWithRed:0 green:0.9 blue:1 alpha:1];
    [fab setTitle:@"ZH" forState:UIControlStateNormal];
    [fab setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    fab.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    fab.layer.shadowColor = [UIColor cyanColor].CGColor;
    fab.layer.shadowOpacity = 0.8;
    fab.layer.shadowRadius = 12;
    [fab addTarget:self action:@selector(expand) forControlEvents:UIControlEventTouchUpInside];
    fab.hidden = YES;

    UIPanGestureRecognizer *p = [[UIPanGestureRecognizer alloc]
                                  initWithTarget:self action:@selector(onPan:)];
    [fab addGestureRecognizer:p];
    [self.view addSubview:fab];
}

- (CGFloat)addToggle:(NSString *)name y:(CGFloat)y tag:(NSInteger)tag def:(BOOL)def {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(12, y, panel.bounds.size.width-24, 34)];
    row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    row.layer.cornerRadius = 9;

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 180, 34)];
    l.text = name;
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [row addSubview:l];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(row.bounds.size.width-58, 2, 51, 31)];
    sw.onTintColor = [UIColor colorWithRed:0 green:0.9 blue:1 alpha:1];
    sw.tag = tag;
    sw.on = def;
    [sw addTarget:self action:@selector(onSw:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];

    [panel addSubview:row];
    return y + 38;
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

- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint t = [g translationInView:self.view];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.view];
}

- (void)collapse {
    [UIView animateWithDuration:0.25 animations:^{
        self->panel.alpha = 0;
        self->panel.transform = CGAffineTransformMakeScale(0.3, 0.3);
    } completion:^(BOOL f) {
        self->panel.hidden = YES;
        self->fab.hidden = NO;
        self->expanded = NO;
    }];
}
- (void)expand {
    panel.hidden = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self->panel.alpha = 1;
        self->panel.transform = CGAffineTransformIdentity;
    } completion:^(BOOL f) {
        self->fab.hidden = YES;
        self->expanded = YES;
    }];
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
