;;; -*- lexical-binding: t; -*-

(defmacro with-terminal-here-mocks (&rest body)
  "Stub out some process interaction functions"
  `(with-mock
     (stub set-process-sentinel)
     (stub set-process-query-on-exit-flag)
     ,@body))

(ert-deftest windows-default-command-integration-test ()
  (with-terminal-here-mocks
   (mock (start-process "cmd.exe" *  "cmd.exe" "/C" "start" "cmd.exe"))
   (let ((system-type 'windows-nt))
     (custom-reevaluate-setting 'terminal-here-terminal-command)
     (terminal-here-launch-in-directory "adir"))))



(ert-deftest terminal-here-launch-alias ()
  (with-terminal-here-mocks
   (mock (terminal-here-launch-in-directory *))
   (terminal-here)))

(ert-deftest linux-default-command ()
  (let ((system-type 'gnu/linux))
    (custom-reevaluate-setting 'terminal-here-terminal-command)
    (should (equal (terminal-here--term-command "adir")
                   '("x-terminal-emulator")))))

(ert-deftest osx-default-command ()
  (let ((system-type 'darwin))
    (custom-reevaluate-setting 'terminal-here-terminal-command)
    (should (equal (terminal-here--term-command "adir")
                   '("open" "-a" "Terminal.app" ".")))))

(ert-deftest windows-default-command ()
  (let ((system-type 'windows-nt))
    (custom-reevaluate-setting 'terminal-here-terminal-command)
    (should (equal (terminal-here--term-command "adir")
                   '("cmd.exe" "/C" "start" "cmd.exe")))))

(ert-deftest no-terminal-for-os-found ()
  (let ((system-type 'foo))
    (custom-reevaluate-setting 'terminal-here-terminal-command)
    (should-error
     (terminal-here--term-command "adir")
     :type 'user-error)))



(ert-deftest custom-terminal-command-as-list ()
  (let ((terminal-here-terminal-command '("1" "2" "3")))
    (should (equal (terminal-here--term-command "adir")
                   '("1" "2" "3")))))

(ert-deftest custom-terminal-command-as-function ()
  (let ((terminal-here-terminal-command (lambda (dir) (list "1" "2" "3" dir))))
    (should (equal (terminal-here--term-command "adir")
                   '("1" "2" "3" "adir")))))

(ert-deftest custom-terminal-command-os-then-command-lookup ()
  (let ((terminal-here-terminal-command (list
                                         (cons 'gnu/linux 'foo)
                                         (cons 'msdos 'bar)
                                         (cons 'darwin 'iterm-app)))
        (system-type 'darwin))
    (should (equal (terminal-here--term-command "foo")
                   (list "open" "-a" "iTerm.app" ".")))))

(ert-deftest custom-terminal-command-os-missing ()
  (let ((system-type 'foo))
    (should-error (terminal-here--term-command "foo") :type 'user-error)))

(ert-deftest custom-terminal-command-as-symbol-lookup ()
  (let ((terminal-here-terminal-command 'iterm-app))
    (should (equal (terminal-here--term-command "foo")
                   (list "open" "-a" "iTerm.app" ".")))))

(ert-deftest custom-terminal-command-as-symbol-not-in-table ()
  (let ((terminal-here-terminal-command 'foo))
    (should-error (terminal-here--term-command "adir") :type 'user-error)))

(ert-deftest custom-terminal-command-customization ()
  (validate-setq terminal-here-terminal-command (list "1" "2" "3"))
  (validate-setq terminal-here-terminal-command (lambda (dir) (list "1" "2" "3" dir)))
  (validate-setq terminal-here-terminal-command (list (cons 'gnu/linux 'foo)))
  (validate-setq terminal-here-terminal-command (list (cons 'gnu/linux (list "1" "2" "3"))))
  (validate-setq terminal-here-terminal-command (list (cons 'gnu/linux (lambda (dir) (list "1" "2" "3" dir)))))
  (should-error (validate-setq terminal-here-terminal-command "astring") :type 'user-error)
  )

(ert-deftest custom-command-flag-customization ()
  (validate-setq terminal-here-command-flag "-k"))

(ert-deftest custom-command-flag-os-then-command-table-lookup ()
  (let ((terminal-here-command-flag nil)
        (system-type 'gnu/linux)
        (terminal-here-terminal-command (list (cons 'gnu/linux 'urxvt))))
    (should (equal (terminal-here--get-command-flag) "-e"))))

(ert-deftest custom-command-flag-table-lookup ()
  (let ((terminal-here-command-flag nil)
        (terminal-here-terminal-command 'urxvt))
    (should (equal (terminal-here--get-command-flag) "-e"))))

(ert-deftest custom-command-flag-main-variable-overrides ()
  (let ((terminal-here-command-flag "-k")
        (terminal-here-terminal-command 'urxvt))
    (should (equal (terminal-here--get-command-flag) "-k"))))

(ert-deftest custom-command-flag-table-lookup-missing-terminal ()
  (let ((terminal-here-command-flag nil)
        (terminal-here-terminal-command 'foo))
    (should-error (terminal-here--get-command-flag) :type 'user-error)))

(ert-deftest custom-command-flag-table-lookup-nothing-configured ()
  (let ((terminal-here-command-flag nil)
        (terminal-here-terminal-command '("foo")))
    (should-error (terminal-here--get-command-flag) :type 'user-error)))



(ert-deftest no-project-root-function ()
  (validate-setq terminal-here-project-root-function nil)
  (cl-letf (((symbol-function #'projectile-project-root) nil)
            ((symbol-function #'vc-root-dir) nil))
    (should-error (terminal-here-project-launch) :type 'user-error)))

(ert-deftest default-project-root-function ()
  (validate-setq terminal-here-project-root-function nil)
  (cl-letf (((symbol-function #'projectile-project-root) (lambda () "" "projectile-root"))
            ((symbol-function #'vc-root-dir) nil))
    (with-terminal-here-mocks
     (mock (terminal-here-launch-in-directory "projectile-root"))
     (terminal-here-project-launch))))

(ert-deftest with-project-root-function ()
  (let ((project-root-finder (lambda () "" "vc-root"))
        (terminal-here-terminal-command '("x-terminal-emulator")))
    (validate-setq terminal-here-project-root-function project-root-finder)
    (with-terminal-here-mocks
     (mock (terminal-here--run-command * "vc-root"))
     (terminal-here-project-launch))))

(ert-deftest project-root-finds-nothing ()
  (validate-setq terminal-here-project-root-function (lambda () nil))
  (should-error (terminal-here-project-launch :type 'user-error)))



(ert-deftest sudo-tramp ()
  (let ((terminal-here-terminal-command '("x-terminal-emulator")))
    (with-terminal-here-mocks
     (mock (terminal-here--run-command * "/etc/emacs/"))
     (terminal-here-launch-in-directory "/sudo:root@localhost:/etc/emacs/"))

    (with-terminal-here-mocks
     (mock (terminal-here--run-command * "/etc/emacs/"))
     (terminal-here-launch-in-directory "/sudo:postgres@localhost:/etc/emacs/"))

    (with-terminal-here-mocks
     (mock (terminal-here--run-command *  "/etc/emacs/"))
     (terminal-here-launch-in-directory "/sudo:root@127.0.0.1:/etc/emacs/"))))



(ert-deftest parse-ssh-dir ()
  (let ((terminal-here-terminal-command '("x-terminal-emulator")))
    (should (equal (terminal-here--parse-ssh-dir "/ssh:buildbot:/home/buildbot/") (list "buildbot" "/home/buildbot/")))
    (should (equal (terminal-here--parse-ssh-dir "/ssh:david@pi:/home/pi/") (list "david@pi" "/home/pi/")))
    (should (equal (terminal-here--parse-ssh-dir "/ssh:root@192.168.0.1:/etc/hosts") (list "root@192.168.0.1" "/etc/hosts")))
    (should (equal (terminal-here--parse-ssh-dir "/ssh:myhost:/home/me/colon:dir") (list "myhost" "/home/me/colon:dir")))
    (should-not (terminal-here--parse-ssh-dir "/home/buildbot/"))
    (should-not (terminal-here--parse-ssh-dir "/ssh/foo/bar"))))

(ert-deftest ssh-tramp ()
  (cl-letf* ((launch-command nil)
             (terminal-here-terminal-command '("x-terminal-emulator"))
             ((symbol-function 'terminal-here--run-command)
              (lambda (command _dir)
                (setq launch-command command))))
    (validate-setq terminal-here-command-flag "-k")
    (terminal-here-launch-in-directory "/ssh:david@pi:/home/pi/")
    (should (equal (car launch-command) "x-terminal-emulator"))
    (should (equal (cadr launch-command) "-k"))
    (should (equal (caddr launch-command) "ssh"))))
