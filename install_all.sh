# Set up the cross compilation envirioment variables for the buildroot toolchain
. ./cross_env.sh

# Install the bootmenu application
#cp -vr bootmenu ${TARGET_DIR}/usr/

# Install simple C applicatons
#cp -v modeset ${TARGET_DIR}/usr/bin/
#cp -v drm_test ${TARGET_DIR}/usr/bin/
#cp -v fb_test ${TARGET_DIR}/usr/bin/
#cp -v fb_test2_simple ${TARGET_DIR}/usr/bin/
#cp -v fb_test2_vsync ${TARGET_DIR}/usr/bin/
#cp -v fb_test2_backbuf ${TARGET_DIR}/usr/bin/
#cp -v fb_test2_doublebuf_vbl_pan ${TARGET_DIR}/usr/bin/
#cp -v fb_test2_doublebuf_vbl ${TARGET_DIR}/usr/bin/
#cp -v fb_test2_doublebuf_pan ${TARGET_DIR}/usr/bin/
#cp -v fb_test2_doublebuf ${TARGET_DIR}/usr/bin/

#mkdir -p ${TARGET_DIR}/usr/share/lua/5.1/
#cp -vr LJIT2RenderingManager ${TARGET_DIR}/usr/
#cp -vr libdrm ${TARGET_DIR}/usr/share/lua/5.1/

# Install lua-db
cd lua-db/
make install
cp -vr examples ${TARGET_DIR}/root/
cd ..
