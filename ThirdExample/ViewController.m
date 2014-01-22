//
//  ViewController.m
//  ThirdExample
//
//  Created by Yoshihiro Mizoguchi on 2013/08/18.
//  Copyright (c) 2013年 Yoshihiro Mizoguchi. All rights reserved.
//

#import "ViewController.h"

// 色データ
#define RED   1.0f, 0.0f, 0.0f, 1.0f
#define GREEN 0.0f, 1.0f, 0.0f, 1.0f
#define BLUE  0.0f, 0.0f, 1.0f, 1.0f
#define BLACK 0.0f, 0.0f, 0.0f, 1.0f
#define WHITE 1.0f, 1.0f, 1.0f, 1.0f

// メッシュを2つの三角形で表して GL_TRIANGLES で表示
// 分割するメッシュ数を MESH_X, MESH_Y で指定する
#define MESH_X 5
#define MESH_Y MESH_X
#define MESH_X1 (MESH_X + 1)
#define MESH_Y1 MESH_X1
#define MESH_SIZE (2*3*MESH_X*MESH_Y)
#define MESH_SIZE_XY (2*MESH_SIZE)

// 三角形分割した頂点座標列を入れる (mesh_pointsから自動生成)
GLfloat triangles_points[MESH_SIZE_XY];
// 三角形分割された頂点のテクスチャ座標列を入れる (最初に固定する)
GLfloat texcoords[MESH_SIZE_XY];

// メッシュの各頂点の座標を入れる
typedef struct {
    float x, y;
} point2d_t;
point2d_t* mesh_points[MESH_X1][MESH_Y1];


@interface ViewController () {
    // Shaderへ渡す変換行列
    GLKMatrix4 _modelViewProjectionMatrix;
    // Shaderへ渡すテクスチャ画像
    GLuint _texname;
    // Shaderを定義するプログラム変数
    GLuint _program;
    
    // Shaderとの変数連結用
    GLuint _position;
    GLuint _texcoord;
    GLuint _textureImageUniform;
    GLuint _modelViewUniform;
    
    // 操作音のための変数
    SystemSoundID _swingsound;
    SystemSoundID _buttonsound;
    // 頂点をランダムに移動する状態と固定する2つの状態がある.
    enum {
        MOVING,
        STOPED
    } _clicked;
    // 移動切り替えのためのカウンター
    int _speedcounter;
#define SPEEDCOUNTER_MAX    30
    
}

// Open GL描画管理オブジェクト
@property (strong, nonatomic) EAGLContext *context;
@end

@implementation ViewController

// 最初に1回実行される
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _clicked = MOVING;
    _speedcounter = 0;
    
    for(int x=0;x<=(MESH_X);x++) {
        for(int y=0;y<=(MESH_Y);y++) {
            mesh_points[x][y]=malloc((sizeof(point2d_t)));
            mesh_points[x][y]->x=(float)x/((float)MESH_X);
            mesh_points[x][y]->y=(float)y/((float)MESH_Y);
        }
    }
    
#define TC_LEFT_BOTTOM_X(i,j)       ((float)i/((float)MESH_X))
#define TC_LEFT_BOTTOM_Y(i,j)       (1.0f-(float)j/((float)MESH_Y))
#define TC_RIGHT_BOTTOM_X(i,j)      ((float)(i+1)/((float)MESH_X))
#define TC_RIGHT_BOTTOM_Y(i,j)      (1.0f-(float)j/((float)MESH_Y))
#define TC_LEFT_TOP_X(i,j)          ((float)i/((float)MESH_X))
#define TC_LEFT_TOP_Y(i,j)          (1.0f-(float)(j+1)/((float)MESH_Y))
#define TC_RIGHT_TOP_X(i,j)         ((float)(i+1)/((float)MESH_X))
#define TC_RIGHT_TOP_Y(i,j)         (1.0f-(float)(j+1)/((float)MESH_Y))
    
#define TC_INDEX(i,j)               (12*((MESH_Y)*i+j))
    
    for(int x=0;x<(MESH_X);x++) {
        for(int y=0;y<(MESH_Y);y++) {
            texcoords[TC_INDEX(x,y)+0]=TC_LEFT_BOTTOM_X(x,y);
            texcoords[TC_INDEX(x,y)+1]=TC_LEFT_BOTTOM_Y(x,y);
            texcoords[TC_INDEX(x,y)+2]=TC_RIGHT_BOTTOM_X(x,y);
            texcoords[TC_INDEX(x,y)+3]=TC_RIGHT_BOTTOM_Y(x,y);
            texcoords[TC_INDEX(x,y)+4]=TC_LEFT_TOP_X(x,y);
            texcoords[TC_INDEX(x,y)+5]=TC_LEFT_TOP_Y(x,y);
            
            texcoords[TC_INDEX(x,y)+6]=TC_LEFT_TOP_X(x,y);
            texcoords[TC_INDEX(x,y)+7]=TC_LEFT_TOP_Y(x,y);
            texcoords[TC_INDEX(x,y)+8]=TC_RIGHT_BOTTOM_X(x,y);
            texcoords[TC_INDEX(x,y)+9]=TC_RIGHT_BOTTOM_Y(x,y);
            texcoords[TC_INDEX(x,y)+10]=TC_RIGHT_TOP_X(x,y);
            texcoords[TC_INDEX(x,y)+11]=TC_RIGHT_TOP_Y(x,y);
        }
    }
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    [EAGLContext setCurrentContext:self.context];
    
    // マウス入力があるとhandleTapFromを呼ぶようにする
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
    [self.view addGestureRecognizer:tapRecognizer];
    
    // vertex shader (VertexShader.vsh を参照するようにする)
    NSString *vertexShaderSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"VertexShader" ofType:@"vsh"] encoding:NSUTF8StringEncoding error:nil];
    const char *vertexShaderSourceCString = [vertexShaderSource cStringUsingEncoding:NSUTF8StringEncoding];
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSourceCString, NULL);
    glCompileShader(vertexShader);
    // fragment shader (FragmentShader.fsh を参照するようにする)
    NSString *fragmentShaderSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"FragmentShader" ofType:@"fsh"] encoding:NSUTF8StringEncoding error:nil];
    const char *fragmentShaderSourceCString = [fragmentShaderSource cStringUsingEncoding:NSUTF8StringEncoding];
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSourceCString, NULL);
    glCompileShader(fragmentShader);
    // Create and link program
    _program = glCreateProgram();
    glAttachShader(_program, vertexShader);
    glAttachShader(_program, fragmentShader);
    glLinkProgram(_program);
    
    // shaderとの変数や配列の連結
    _position = glGetAttribLocation(_program, "position");
    _texcoord = glGetAttribLocation(_program, "texcoord");
    glEnableVertexAttribArray(_position);
    glEnableVertexAttribArray(_texcoord);
    _textureImageUniform = glGetUniformLocation(_program, "textureImage");
    _modelViewUniform = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    
    // texture画像の読み込み (_texname)
    CGImageRef spriteImage = [UIImage imageNamed:@"fruit.png"].CGImage;
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    GLubyte * spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4, CGImageGetColorSpace(spriteImage), (CGBitmapInfo) kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    CGContextRelease(spriteContext);
    glGenTextures(1, &_texname);
    glBindTexture(GL_TEXTURE_2D, _texname);
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER , GL_LINEAR );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    free(spriteData);
    
    // 操作音の読み込み (_swingsound, _buttonsound)
    NSURL *soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"b2-034_swing_10" ofType:@"mp3"]];
    AudioServicesCreateSystemSoundID((CFURLRef)soundURL, &_swingsound);
    soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"b1-002_button_01" ofType:@"mp3"]];
    AudioServicesCreateSystemSoundID((CFURLRef)soundURL, &_buttonsound);
    
    // 最初は移動状態なので _swingsoundを再生する
    AudioServicesPlaySystemSound(_swingsound);
    
}

// マウス入力時に呼ばれる関数 (クリック位置の上下で仰角を増減)
- (void)handleTapFrom:(UITapGestureRecognizer *)recognizer {
    CGPoint touchLocation = [recognizer locationInView:recognizer.view];
    touchLocation = CGPointMake(touchLocation.x, self.view.bounds.size.height - touchLocation.y);
    NSLog(@"touchopoint(%f,%f)",touchLocation.x,touchLocation.y);
    NSLog(@"npoint(%f,%f)",(touchLocation.x/self.view.bounds.size.width-0.5f)*2.0f,
                            (touchLocation.y/self.view.bounds.size.height-0.5f));
    NSLog(@"bounds(%f,%f)",self.view.bounds.size.width,self.view.bounds.size.height);

    if (_clicked==MOVING) {
        _clicked=STOPED;
        for(int x=0;x<=MESH_X;x++) {
            for(int y=0;y<=MESH_Y;y++) {
                mesh_points[x][y]->x=(float)x/((float)MESH_X);
                mesh_points[x][y]->y=(float)y/((float)MESH_Y);
            }
        }
        AudioServicesPlaySystemSound(_buttonsound);
    } else {
        _clicked=MOVING;
        AudioServicesPlaySystemSound(_swingsound);
    }
}

- (void)update
{
    // 何も書かないがメソッドは準備しておく (viewが呼ばれる)
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    // 背景は緑にする.
    glClearColor(GREEN);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Shaderプログラムを指定する.
    glUseProgram(_program);
    
    // 画面サイズの調整
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    // GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-0.5f, 1.5f, -0.5f/aspect, 1.5f/aspect, 0.0f, 1.0f);
    // 視点は(x,y)=(0.5,0.5)が中心に見えるように上下左右に移動し, z軸方向は少し下がる.
    // GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(-0.5f, -0.5f, -1.5f);
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(-0.0f, -0.0f, 0.0f);
    // 変換行列を指定する.
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    glUniformMatrix4fv(_modelViewUniform, 1, 0, _modelViewProjectionMatrix.m);
    
    // Textureを指定し, テクスチャ座標を指定する.
    glBindTexture(GL_TEXTURE_2D, _texname);
    glUniform1i(_textureImageUniform, 0);
    glVertexAttribPointer(_texcoord, 2, GL_FLOAT, GL_FALSE, 0, texcoords);
    glEnableVertexAttribArray(_texcoord);
    
    // MOVING状態のときは, 図形の頂点座標をランダムに移動する.
    if ((_clicked==MOVING)&&(_speedcounter==0)) {
        _speedcounter++;
        float random_maxx = 0.3f/((float)MESH_X);
        float random_maxy = 0.3f/((float)MESH_Y);
        for(int x=0;x<=MESH_X;x++) {
            for(int y=0;y<=MESH_Y;y++) {
                float rx=2.0f*((float)rand())/((float)(RAND_MAX))-1.0f;
                float ry=2.0f*((float)rand())/((float)(RAND_MAX))-1.0f;
                mesh_points[x][y]->x=rx*random_maxx+(float)x/((float)MESH_X);
                mesh_points[x][y]->y=ry*random_maxy+(float)y/((float)MESH_Y);
            }
        }
    } else {
        _speedcounter++;
        if (_speedcounter==SPEEDCOUNTER_MAX) _speedcounter=0;
    }
    
#define MS_LEFT_BOTTOM_X(i,j)       (mesh_points[i][j]->x)
#define MS_LEFT_BOTTOM_Y(i,j)       (mesh_points[i][j]->y)
#define MS_RIGHT_BOTTOM_X(i,j)      (mesh_points[i+1][j]->x)
#define MS_RIGHT_BOTTOM_Y(i,j)      (mesh_points[i+1][j]->y)
#define MS_LEFT_TOP_X(i,j)          (mesh_points[i][j+1]->x)
#define MS_LEFT_TOP_Y(i,j)          (mesh_points[i][j+1]->y)
#define MS_RIGHT_TOP_X(i,j)         (mesh_points[i+1][j+1]->x)
#define MS_RIGHT_TOP_Y(i,j)         (mesh_points[i+1][j+1]->y)
    
    for(int x=0;x<(MESH_X);x++) {
        for(int y=0;y<(MESH_Y);y++) {
            triangles_points[TC_INDEX(x,y)+0]=MS_LEFT_BOTTOM_X(x,y);
            triangles_points[TC_INDEX(x,y)+1]=MS_LEFT_BOTTOM_Y(x,y);
            triangles_points[TC_INDEX(x,y)+2]=MS_RIGHT_BOTTOM_X(x,y);
            triangles_points[TC_INDEX(x,y)+3]=MS_RIGHT_BOTTOM_Y(x,y);
            triangles_points[TC_INDEX(x,y)+4]=MS_LEFT_TOP_X(x,y);
            triangles_points[TC_INDEX(x,y)+5]=MS_LEFT_TOP_Y(x,y);
            
            triangles_points[TC_INDEX(x,y)+6]=MS_LEFT_TOP_X(x,y);
            triangles_points[TC_INDEX(x,y)+7]=MS_LEFT_TOP_Y(x,y);
            triangles_points[TC_INDEX(x,y)+8]=MS_RIGHT_BOTTOM_X(x,y);
            triangles_points[TC_INDEX(x,y)+9]=MS_RIGHT_BOTTOM_Y(x,y);
            triangles_points[TC_INDEX(x,y)+10]=MS_RIGHT_TOP_X(x,y);
            triangles_points[TC_INDEX(x,y)+11]=MS_RIGHT_TOP_Y(x,y);
        }
    }
    
    // 頂点座標を指定して描画する.
    glVertexAttribPointer(_position, 2, GL_FLOAT, GL_FALSE, 0, triangles_points);
    glEnableVertexAttribArray(_position);
    glDrawArrays(GL_TRIANGLES, 0, MESH_SIZE);
}

@end