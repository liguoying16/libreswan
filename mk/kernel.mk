# Libreswan master makefile
#
# Copyright (C) 1998-2002  Henry Spencer.
# Copyright (C) 2003-2004  Xelerance Corporation
# Copyright (C) 2017, Richard Guy Briggs <rgb@tricolour.ca>
# Copyright (C) 2015-2018  Andrew Cagney
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.  See <https://www.gnu.org/licenses/gpl2.txt>.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#

PATCHES=linux
# where KLIPS goes in the kernel
# note, some of the patches know the last part of this path
KERNELKLIPS=$(KERNELSRC)/net/ipsec
KERNELCRYPTODES=$(KERNELSRC)/crypto/ciphers/des
KERNELLIBFREESWAN=$(KERNELSRC)/lib/libfreeswan
KERNELLIBZLIB=$(KERNELSRC)/lib/zlib
KERNELINCLUDE=$(KERNELSRC)/include

MAKEUTILS=packaging/utils
ERRCHECK=${MAKEUTILS}/errcheck
KVUTIL=${MAKEUTILS}/kernelversion
KVSHORTUTIL=${MAKEUTILS}/kernelversion-short

# kernel details
# what variant of our patches should we use, and where is it
KERNELREL=$(shell ${KVSHORTUTIL} ${KERNELSRC}/Makefile)

# directories visited by all recursion

# declaration for make's benefit
.PHONY:	def insert kpatch patches _patches _patches2.4 \
	klipsdefaults programs man install \
	precheck verset confcheck kernel \
	module module24 module26 kinstall minstall minstall24 minstall26 \
	moduleclean mod24clean module24clean mod26clean module26clean \
	backup unpatch uninstall \
	check \

kpatch: unapplypatch applypatch klipsdefaults
npatch: unapplynpatch applynpatch
sarefpatch: unapplysarefpatch applysarefpatch

unapplypatch:
	@echo "info: making unapplypatch in `pwd` and KERNELSRC=\"${KERNELSRC}\";"
	-@if [ -f ${KERNELSRC}/libreswan.patch ]; then \
		echo Undoing previous patches; \
		cat ${KERNELSRC}/libreswan.patch | (cd ${KERNELSRC} && patch -p1 -R --force -E -z .preipsec --reverse --ignore-whitespace ); \
	fi

applypatch:
	@echo "info: Now performing forward patches in `pwd`";
	${MAKE} kernelpatch${KERNELREL} | tee ${KERNELSRC}/libreswan.patch | (cd ${KERNELSRC} && patch -p1 -b -z .preipsec --forward --ignore-whitespace )

unapplynpatch:
	@echo "info: making unapplynpatch (note the second N) in `pwd`";
	-@if [ -f ${KERNELSRC}/natt.patch ]; then \
		echo Undoing previous NAT patches; \
		cat ${KERNELSRC}/natt.patch | (cd ${KERNELSRC} && patch -p1 -R --force -E -z .preipsec --reverse --ignore-whitespace ); \
	fi

applynpatch:
	@echo "info: Now performing forward NAT patches in `pwd`";
	${MAKE} nattpatch${KERNELREL} | tee ${KERNELSRC}/natt.patch | (cd ${KERNELSRC} && patch -p1 -b -z .preipsec --forward --ignore-whitespace )

unapplysarefpatch:
	@echo "info: making unapplysarefpatch in `pwd`";
	-@if [ -f ${KERNELSRC}/saref.patch ]; then \
		echo Undoing previous saref patches; \
		cat ${KERNELSRC}/saref.patch | (cd ${KERNELSRC} && patch -p1 -R --force -E -z .preng --reverse --ignore-whitespace ); \
	fi

applysarefpatch:
	@echo "info: Now performing SAref patches in `pwd`";
	${MAKE} sarefpatch${KERNELREL} | tee ${KERNELSRC}/klipsng.patch | (cd ${KERNELSRC} && patch -p1 -b -z .preng --forward --ignore-whitespace )

# patch kernel
PATCHER=packaging/utils/patcher

_patches:
	echo "===============" >>out.kpatch
	echo "`date` `cd $(KERNELSRC) ; pwd`" >>out.kpatch
	$(MAKE) __patches$(KERNELREL) >>out.kpatch

# Linux-2.4.0 version
__patches2.4:
	@$(PATCHER) -v -c $(KERNELSRC) Documentation/Configure.help \
		'CONFIG_KLIPS' $(PATCHES)/Documentation/Configure.help.fs2_2.patch
	@$(PATCHER) -v $(KERNELSRC) net/Config.in \
		'CONFIG_KLIPS' $(PATCHES)/net/Config.in.fs2_4.patch
	@$(PATCHER) -v $(KERNELSRC) net/Makefile \
		'CONFIG_KLIPS' $(PATCHES)/net/Makefile.fs2_4.patch
	@$(PATCHER) -v $(KERNELSRC) net/ipv4/af_inet.c \
		'CONFIG_KLIPS' $(PATCHES)/net/ipv4/af_inet.c.fs2_4.patch
	@$(PATCHER) -v $(KERNELSRC) net/ipv4/udp.c \
		'CONFIG_KLIPS' $(PATCHES)/net/ipv4/udp.c.fs2_4.patch
	@$(PATCHER) -v $(KERNELSRC) include/net/sock.h \
		'CONFIG_KLIPS' $(PATCHES)/include/net/sock.h.fs2_4.patch
# Removed patches, will unpatch automatically.
	@$(PATCHER) -v $(KERNELSRC) include/linux/proc_fs.h
	@$(PATCHER) -v $(KERNELSRC) net/core/dev.c
	@$(PATCHER) -v $(KERNELSRC) net/ipv4/protocol.c
	@$(PATCHER) -v $(KERNELSRC) drivers/net/Space.c
	@$(PATCHER) -v $(KERNELSRC) include/linux/netlink.h
	@$(PATCHER) -v $(KERNELSRC) net/netlink/af_netlink.c
	@$(PATCHER) -v $(KERNELSRC) net/netlink/netlink_dev.c
	@$(PATCHER) -v $(KERNELSRC) drivers/isdn/isdn_net.c

klipsdefaults:
	@KERNELDEFCONFIG=$(KERNELSRC)/arch/$(ARCH)/defconfig ; \
	KERNELCONFIG=$(KCFILE) ; \
	if ! grep -E -q 'CONFIG_KLIPS' $$KERNELDEFCONFIG ; \
	then \
		set -x ; \
		cp -a $$KERNELDEFCONFIG $$KERNELDEFCONFIG.orig ; \
		chmod u+w $$KERNELDEFCONFIG ; \
		cat $$KERNELDEFCONFIG $(KERNELKLIPS)/defconfig \
			>$$KERNELDEFCONFIG.tmp ; \
		rm -f $$KERNELDEFCONFIG ; \
		cp -a $$KERNELDEFCONFIG.tmp $$KERNELDEFCONFIG ; \
		rm -f $$KERNELDEFCONFIG.tmp ; \
	fi ; \
	if ! grep -E -q 'CONFIG_KLIPS' $$KERNELCONFIG ; \
	then \
		set -x ; \
		cp -a $$KERNELCONFIG $$KERNELCONFIG.orig ; \
		chmod u+w $$KERNELCONFIG ; \
		cat $$KERNELCONFIG $(KERNELKLIPS)/defconfig \
			>$$KERNELCONFIG.tmp ; \
		rm -f $$KERNELCONFIG ; \
		cp -a $$KERNELCONFIG.tmp $$KERNELCONFIG ; \
		rm -f $$KERNELCONFIG.tmp ; \
	fi


local-clean-base: moduleclean
distclean: moduleclean module24clean module26clean clean-kvm-keys

# proxies for major kernel make operations

# do-everything entries
KINSERT_PRE=precheck verset insert
PRE=precheck verset kpatch
POST=confcheck programs kernel install
MPOST=confcheck programs module install

# preliminaries
precheck:
	@if test ! -d $(KERNELSRC) -a ! -L $(KERNELSRC) ; \
	then \
		echo '*** cannot find directory "$(KERNELSRC)"!!' ; \
		echo '*** may be necessary to add symlink to kernel source' ; \
		exit 1 ; \
	fi
	@if ! cd $(KERNELSRC) ; \
	then \
		echo '*** cannot "cd $(KERNELSRC)"!!' ; \
		echo '*** may be necessary to add symlink to kernel source' ; \
		exit 1 ; \
	fi
	@if test ! -f $(KCFILE) ; \
	then \
		echo '*** cannot find "$(KCFILE)"!!' ; \
		echo '*** perhaps kernel has never been configured?' ; \
		echo '*** please do that first; the results are necessary.' ; \
		exit 1 ; \
	fi
	@if test ! -f $(VERFILE) ; \
	then \
		echo '*** cannot find "$(VERFILE)"!!' ; \
		echo '*** perhaps kernel has never been compiled?' ; \
		echo '*** please do that first; the results are necessary.' ; \
		exit 1 ; \
	fi

# configuring (exit statuses disregarded, something fishy here sometimes)
xcf:
	-cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) xconfig
mcf:
	-cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) menuconfig
pcf:
	-cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) config

ocf:
	-cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) oldconfig

rcf:
	cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) ${NONINTCONFIG} </dev/null
	cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) dep >/dev/null

kclean:
	-cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) clean

confcheck:
	@if test ! -f $(KCFILE) ; \
	then echo '*** no kernel configuration file written!!' ; exit 1 ; \
	fi
	@if ! grep -E -q '^CONFIG_KLIPS=[my]' $(KCFILE) ; \
	then echo '*** IPsec not in kernel config ($(KCFILE))!!' ; exit 1 ; \
	fi
	@if ! grep -E -q 'CONFIG_KLIPS[ 	]+1' $(ACFILE) && \
		! grep -E -q 'CONFIG_KLIPS_MODULE[ 	]+1' $(ACFILE) ; \
	then echo '*** IPsec in kernel config ($(KCFILE)),' ; \
		echo '***	but not in config header file ($(ACFILE))!!' ; \
		exit 1 ; \
	fi
	@if grep -E -q '^CONFIG_KLIPS=m' $(KCFILE) && \
		! grep -E -q '^CONFIG_MODULES=y' $(KCFILE) ; \
	then echo '*** IPsec configured as module in kernel with no module support!!' ; exit 1 ; \
	fi
	@if ! grep -E -q 'CONFIG_KLIPS_AH[ 	]+1' $(ACFILE) && \
		! grep -E -q 'CONFIG_KLIPS_ESP[ 	]+1' $(ACFILE) ; \
	then echo '*** IPsec configuration must include AH or ESP!!' ; exit 1 ; \
	fi

# kernel building, with error checks
kernel:
	rm -f out.kbuild out.kinstall
	# undocumented kernel folklore: clean BEFORE dep.
	# we run make dep separately, because there is no point in running ERRCHECK
	# on the make dep output.
	# see LKML thread "clean before or after dep?"
	( cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) $(KERNCLEAN) $(KERNDEP) )
	( cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) $(KERNEL) ) 2>&1 | tee out.kbuild
	@if grep -E -q '^CONFIG_MODULES=y' $(KCFILE) ; \
	then set -x ; \
		( cd $(KERNELSRC) ; \
		$(MAKE) $(KERNMAKEOPTS) modules 2>&1 ) | tee -a out.kbuild ; \
	fi
	${ERRCHECK} out.kbuild

# module-only building, with error checks
ifneq ($(strip $(MOD24BUILDDIR)),)
${MOD24BUILDDIR}/Makefile : ${LIBRESWANSRCDIR}/packaging/makefiles/module24.make
	mkdir -p ${MOD24BUILDDIR}
	cp ${LIBRESWANSRCDIR}/packaging/makefiles/module24.make ${MOD24BUILDDIR}/Makefile

module:
	@if [ -f ${KERNELSRC}/README.libreswan-2 ] ; then \
                echo "WARNING: Kernel source ${KERNELSRC} has already been patched with libreswan-2, out of tree build might fail!"; \
        fi;
	@if [ -f ${KERNELSRC}/README.openswan ] ; then \
                echo "WARNING: Kernel source ${KERNELSRC} has already been patched with openswan, out of tree build might fail!"; \
        fi;
	@if [ -f ${KERNELSRC}/README.openswan-2 ] ; then \
                echo "WARNING: Kernel source ${KERNELSRC} has already been patched with openswan-2, out of tree build might fail!"; \
        fi;
	@if [ -f ${KERNELSRC}/README.freeswan ] ; then \
                echo "ERROR: Kernel source ${KERNELSRC} has already been patched with freeswan, out of tree build will fail!"; \
        fi;
	@if [ -f ${KERNELSRC}/Rules.make ] ; then \
                echo "Building module for a 2.4 kernel"; ${MAKE} module24 ; \
        else echo "Building module for a 2.6 kernel"; ${MAKE} module26; \
        fi;

modclean moduleclean:
	@if [ -f ${KERNELSRC}/Rules.make ] ; then \
		echo "Cleaning module for a 2.4 kernel"; ${MAKE} module24clean ; \
	else echo "Cleaning module for a 2.6 kernel"; ${MAKE} module26clean; \
	fi;

module24:
	@if [ ! -f ${KERNELSRC}/Rules.make ] ; then \
                echo "Warning: Building for a 2.4 kernel in what looks like a 2.6 tree"; \
        fi ; \
        ${MAKE} ${MOD24BUILDDIR}/Makefile
	${MAKE} -C ${MOD24BUILDDIR}  LIBRESWANSRCDIR=${LIBRESWANSRCDIR} ARCH=${ARCH} V=${V} ${MODULE_FLAGS} MODULE_DEF_INCLUDE=${MODULE_DEF_INCLUDE} TOPDIR=${KERNELSRC} -f Makefile ipsec.o
	@echo
	@echo '========================================================='
	@echo
	@echo 'KLIPS24 module built successfully. '
	@echo ipsec.o is in ${MOD24BUILDDIR}
	@echo
	@(cd ${MOD24BUILDDIR}; ls -l ipsec.o)
	@(cd ${MOD24BUILDDIR}; size ipsec.o)
	@echo
	@echo 'use make minstall as root to install it'
	@echo
	@echo '========================================================='
	@echo

mod24clean module24clean:
	rm -rf ${MOD24BUILDDIR}

#autoodetect 2.4 and 2.6
module_install minstall install-module:
	@if [ -f $(KERNELSRC)/Rules.make ] ; then \
                $(MAKE) minstall24 ; \
	else \
		$(MAKE) minstall26 ; \
        fi;

# Extract the value of MODLIB from the output of $(MAKE).  Also hide
# the sup-process $(MAKE) so that GNU Make doesn't always invoke the
# target ("make -n" ignored).
#
# If $(MAKE) directly appears in a target (for instance in minstall26)
# then GNU Make will assume that it is a recursive make invocation and
# invoke the target regardless of -n.
#
# XXX: minstall24 should also use this.

osmodlib-from-make = \
	OSMODLIB=$$($(MAKE) $(1) 2>/dev/null | sed -n -e 's/^MODLIB[ :=]*\([^;]*\).*/\1/p' | head -1) ; \
	test -z "$$OSMODLIB" || echo "OSMODLIB=$$OSMODLIB ($(MAKE) $(1))"

# module-only install, with error checks
minstall24:
	( OSMODLIB=`${MAKE} -C $(KERNELSRC) -p dummy | ( sed -n -e '/^MODLIB/p' -e '/^MODLIB/q' ; cat > /dev/null ) | sed -e 's/^MODLIB[ :=]*\([^;]*\).*/\1/'` ; \
	if [ -z "$$OSMODLIB" ] ; then \
		OSMODLIB=`${MAKE} -C $(KERNELSRC) -n -p modules_install | ( sed -n -e '/^MODLIB/p' -e '/^MODLIB/q' ; cat > /dev/null ) | sed -e 's/^MODLIB[ :=]*\([^;]*\).*/\1/'` ; \
	fi ; \
	if [ -z "$$OSMODLIB" ] ; then \
		echo "No known place to install module. Aborting." ; \
		exit 93 ; \
	fi ; \
	set -x ; \
	mkdir -p $$OSMODLIB/kernel/$(OSMOD_DESTDIR) ; \
	cp $(MOD24BUILDDIR)/ipsec.o $$OSMODLIB/kernel/$(OSMOD_DESTDIR) ; \
	if [ -f /sbin/depmod ] ; then /sbin/depmod -a ; fi; \
	if [ -n "$(OSMOD_DESTDIR)" ] ; then \
        mkdir -p $$OSMODLIB/kernel/$(OSMOD_DESTDIR) ; \
                if [ -f $$OSMODLIB/kernel/ipsec.o -a -f $$OSMODLIB/kernel/$(OSMOD_DESTDIR)/ipsec.o ] ; then \
                        echo "WARNING: two ipsec.o modules found in $$OSMODLIB/kernel:" ; \
                        ls -l $$OSMODLIB/kernel/ipsec.o $$OSMODLIB/kernel/$(OSMOD_DESTDIR)/ipsec.o ; \
                        exit 1; \
                fi ; \
        fi ; \
        set -x ) ;


else
module:
	echo 'Building in place is no longer supported. Please set MOD24BUILDDIR='
	exit 1

endif

# module-only building, with error checks
ifneq ($(strip $(MODBUILDDIR)),)
${MODBUILDDIR}/Makefile : ${LIBRESWANSRCDIR}/packaging/makefiles/module.make
	mkdir -p ${MODBUILDDIR}
	echo ln -s -f ${LIBRESWANSRCDIR}/linux/net/ipsec/des/*.S ${MODBUILDDIR}
	(rm -f ${MODBUILDDIR}/des; mkdir -p ${MODBUILDDIR}/des && cd ${MODBUILDDIR}/des && ln -s -f ${LIBRESWANSRCDIR}/linux/net/ipsec/des/* . && ln -s -f Makefile.fs2_6 Makefile)
	(rm -f ${MODBUILDDIR}/aes; mkdir -p ${MODBUILDDIR}/aes && cd ${MODBUILDDIR}/aes && ln -s -f ${LIBRESWANSRCDIR}/linux/net/ipsec/aes/* . && ln -s -f Makefile.fs2_6 Makefile)
	mkdir -p ${MODBUILDDIR}/aes
	cp ${LIBRESWANSRCDIR}/packaging/makefiles/module.make ${MODBUILDDIR}/Makefile
	ln -s -f ${LIBRESWANSRCDIR}/linux/net/ipsec/match*.S ${MODBUILDDIR}

module26:
	@if [ -f ${KERNELSRC}/Rules.make ] ; then \                 echo "Warning: Building for a 2.6+ kernel in what looks like a 2.4 tree"; \
        fi ; \
        ${MAKE}  ${MODBUILDDIR}/Makefile
	${MAKE} -C ${KERNELSRC} ${KERNELBUILDMFLAGS} BUILDDIR=${MODBUILDDIR} SUBDIRS=${MODBUILDDIR} INITSYSTEM=$(INITSYSTEM) MODULE_DEF_INCLUDE=${MODULE_DEF_INCLUDE} MODULE_DEFCONFIG=${MODULE_DEFCONFIG}  MODULE_EXTRA_INCLUDE=${MODULE_EXTRA_INCLUDE} ARCH=${ARCH} V=${V} modules
	@echo
	@echo '========================================================='
	@echo
	@echo 'KLIPS module built successfully. '
	@echo ipsec.ko is in ${MODBUILDDIR}
	@echo
	@(cd ${MODBUILDDIR}; ls -l ipsec.ko)
	@(cd ${MODBUILDDIR}; size ipsec.ko)
	@echo
	@echo 'use make minstall as root to install it'
	@echo
	@echo '========================================================='
	@echo

mod26clean module26clean:
	rm -rf ${MODBUILDDIR}

# module-only install, with error checks
minstall26:
	$(call osmodlib-from-make,-C $(KERNELSRC) -p help) ; \
	if [ -z "$$OSMODLIB" ] ; then \
		$(call osmodlib-from-make,-C $(KERNELSRC) -n -p modules_install) ; \
	fi ; \
	if [ -z "$$OSMODLIB" ] ; then \
		echo "No known place to install module. Aborting." ; \
		exit 93 ; \
	fi ; \
	set -x ; \
	mkdir -p $$OSMODLIB/kernel/$(OSMOD_DESTDIR) ; \
	cp $(MODBUILDDIR)/ipsec.ko $$OSMODLIB/kernel/$(OSMOD_DESTDIR) ; \
	if [ -f /sbin/depmod ] ; then \
		/sbin/depmod -a ; \
	fi ; \
	if [ -n "$(OSMOD_DESTDIR)" ] ; then \
		mkdir -p $$OSMODLIB/kernel/$(OSMOD_DESTDIR) ; \
		if [ -f $$OSMODLIB/kernel/ipsec.ko -a -f $$OSMODLIB/kernel/$(OSMOD_DESTDIR)/ipsec.ko ] ; then \
			echo "WARNING: two ipsec.ko modules found in $$OSMODLIB/kernel:" ; \
			ls -l $$OSMODLIB/kernel/ipsec.ko $$OSMODLIB/kernel/$(OSMOD_DESTDIR)/ipsec.ko ; \
			exit 1; \
		fi ; \
	fi


else
module26:
	echo 'Building in place is no longer supported. Please set MODBUILDDIR='
	exit 1

endif

# kernel install, with error checks
kinstall:
	rm -f out.kinstall
	>out.kinstall
	# undocumented kernel folklore: modules_install must precede install (observed on RHL8.0)
	@if grep -E -q '^CONFIG_MODULES=y' $(KCFILE) ; \
	then set -x ; \
		( cd $(KERNELSRC) ; \
		$(MAKE) $(KERNMAKEOPTS) modules_install 2>&1 ) | tee -a out.kinstall ; \
	fi
	( cd $(KERNELSRC) ; $(MAKE) $(KERNMAKEOPTS) install ) 2>&1 | tee -a out.kinstall
	${ERRCHECK} out.kinstall

kernelpatch3 kernelpatch3.5 kernelpatch2.6 kernelpatch:
	packaging/utils/kernelpatch 2.6

kernelpatch2.4:
	packaging/utils/kernelpatch 2.4

nattpatch:
	if [ -f ${KERNELSRC}/Makefile ]; then \
		${MAKE} nattpatch${KERNELREL}; \
	else	echo "Cannot determine Linux kernel version. Perhaps you need to set KERNELSRC? (eg: export KERNELSRC=/usr/src/linux-`uname -r`/)"; exit 1; \
	fi;

sarefpatch2.6:
	#cat patches/kernel/2.6.38/0001-SAREF-add-support-for-SA-selection-through-sendmsg.patch
	#packaging/utils/sarefpatch 2.6
	echo ""

nattpatch2.6:
	packaging/utils/nattpatch 2.6

nattpatch2.4:
	packaging/utils/nattpatch 2.4

nattupdate:
	(cd UMLPOOL && diff -u plain26/net/ipv4/udp.c.orig plain26/net/ipv4/udp.c; exit 0) >nat-t/net/ipv4/udp.c.os2_6.patch

# take all the patches out of the kernel
# (Note, a couple of files are modified by non-patch means; they are
# included in "make backup".)
unpatch:
	@echo \"make unpatch\" is obsolete. See make unapplypatch.
	exit 1

_unpatch:
	for f in `find $(KERNELSRC)/. -name '*.preipsec' -print` ; \
	do \
		echo "restoring $$f:" ; \
		dir=`dirname $$f` ; \
		core=`basename $$f .preipsec` ; \
		cd $$dir ; \
		mv -f $$core.preipsec $$core ; \
		rm -f $$core.wipsec $$core.ipsecmd5 ; \
	done
