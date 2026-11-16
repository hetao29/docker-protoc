<?php
// Usage: php test/php-runtime.php GENERATED_PHP_DIR PROTOBUF_AUTOLOAD_PHP PUBLIC_FIXTURE_DIR
declare(strict_types=1);
if ($argc !== 4) {
    throw new InvalidArgumentException('Expected generated PHP directory, protobuf autoloader and fixture directory');
}
require $argv[2];
$generated = $argv[1];
$fixture = $argv[3];
spl_autoload_register(static function (string $class) use ($generated, $fixture): void {
    foreach ([$generated, $fixture] as $root) {
        $file = $root . '/' . str_replace('\\', '/', $class) . '.php';
        if (is_file($file)) {
            require $file;
            return;
        }
    }
});
$request = new Test\HelloRequest();
$request->setName('toolchain-upgrade');
$copy = new Test\HelloRequest();
$copy->mergeFromString($request->serializeToString());
if (!$copy->hasName() || $copy->getName() !== 'toolchain-upgrade') {
    throw new RuntimeException('Optional string round trip failed');
}
$copy->clearName();
if ($copy->hasName()) {
    throw new RuntimeException('Optional presence was not cleared');
}
$message = new Compatibility\PublicDependency();
$message->setCreatedAt((new Google\Protobuf\Timestamp())->setSeconds(123));
$restored = new Compatibility\PublicDependency();
$restored->mergeFromString($message->serializeToString());
if ($restored->getCreatedAt()->getSeconds() !== 123) {
    throw new RuntimeException('Public dependency round trip failed');
}
echo 'PHP optional/public dependency round trips passed (', extension_loaded('protobuf') ? 'C extension' : 'pure PHP', ").\n";
