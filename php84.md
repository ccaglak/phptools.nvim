## Property hooks  [RFC](https://wiki.php.net/rfc/property-hooks)  [Doc](https://www.php.net/manual/en/migration84.new-features.php#migration84.new-features.core.property-hooks)[¶](https://www.php.net/releases/8.4/en.php#property_hooks)

PHP < 8.4

```
class Locale
{
    private string $languageCode;
    private string $countryCode;

    public function __construct(string $languageCode, string $countryCode)
    {
        $this->setLanguageCode($languageCode);
        $this->setCountryCode($countryCode);
    }

    public function getLanguageCode(): string
    {
        return $this->languageCode;
    }

    public function setLanguageCode(string $languageCode): void
    {
        $this->languageCode = $languageCode;
    }

    public function getCountryCode(): string
    {
        return $this->countryCode;
    }

    public function setCountryCode(string $countryCode): void
    {
        $this->countryCode = strtoupper($countryCode);
    }

    public function setCombinedCode(string $combinedCode): void
    {
        [$languageCode, $countryCode] = explode('_', $combinedCode, 2);

        $this->setLanguageCode($languageCode);
        $this->setCountryCode($countryCode);
    }

    public function getCombinedCode(): string
    {
        return \sprintf("%s_%s", $this->languageCode, $this->countryCode);
    }
}

$brazilianPortuguese = new Locale('pt', 'br');
var_dump($brazilianPortuguese->getCountryCode()); // BR
var_dump($brazilianPortuguese->getCombinedCode()); // pt_BR
```

PHP 8.4

```
class Locale
{
    public string $languageCode;

    public string $countryCode
    {
        set (string $countryCode) {
            $this->countryCode = strtoupper($countryCode);
        }
    }

    public string $combinedCode
    {
        get => \sprintf("%s_%s", $this->languageCode, $this->countryCode);
        set (string $value) {
            [$this->languageCode, $this->countryCode] = explode('_', $value, 2);
        }
    }

    public function __construct(string $languageCode, string $countryCode)
    {
        $this->languageCode = $languageCode;
        $this->countryCode = $countryCode;
    }
}

$brazilianPortuguese = new Locale('pt', 'br');
var_dump($brazilianPortuguese->countryCode); // BR
var_dump($brazilianPortuguese->combinedCode); // pt_BR
```

Property hooks provide support for computed properties that can natively be understood by IDEs and static analysis tools, without needing to write docblock comments that might go out of sync. Furthermore, they allow reliable pre- or post-processing of values, without needing to check whether a matching getter or setter exists in the class.

## Asymmetric Visibility  [RFC](https://wiki.php.net/rfc/asymmetric-visibility-v2)  [Doc](https://www.php.net/manual/en/language.oop5.visibility.php#language.oop5.visibility-members-aviz)

PHP < 8.4

```
class PhpVersion
{
    private string $version = '8.3';

    public function getVersion(): string
    {
        return $this->version;
    }

    public function increment(): void
    {
        [$major, $minor] = explode('.', $this->version);
        $minor++;
        $this->version = "{$major}.{$minor}";
    }
}
```

PHP 8.4

```
class PhpVersion
{
    public private(set) string $version = '8.4';

    public function increment(): void
    {
        [$major, $minor] = explode('.', $this->version);
        $minor++;
        $this->version = "{$major}.{$minor}";
    }
}
```

The scope to write to a property may now be controlled independently from the scope to read the property, reducing the need for boilerplate getter methods to expose a property’s value without allowing modification from the outside of a class.

## `#[\Deprecated]`  Attribute  [RFC](https://wiki.php.net/rfc/deprecated_attribute)  [Doc](https://www.php.net/manual/en/class.deprecated.php)

PHP < 8.4

```
class PhpVersion
{
    /**
     * @deprecated 8.3 use PhpVersion::getVersion() instead
     */
    public function getPhpVersion(): string
    {
        return $this->getVersion();
    }

    public function getVersion(): string
    {
        return '8.3';
    }
}

$phpVersion = new PhpVersion();
// No indication that the method is deprecated.
echo $phpVersion->getPhpVersion();
```

PHP 8.4

```
class PhpVersion
{
    #[\Deprecated(
        message: "use PhpVersion::getVersion() instead",
        since: "8.4",
    )]
    public function getPhpVersion(): string
    {
        return $this->getVersion();
    }

    public function getVersion(): string
    {
        return '8.4';
    }
}

$phpVersion = new PhpVersion();
// Deprecated: Method PhpVersion::getPhpVersion() is deprecated since 8.4, use PhpVersion::getVersion() instead
echo $phpVersion->getPhpVersion();
```

The new  `#[\Deprecated]`  attribute makes PHP’s existing deprecation mechanism available to user-defined functions, methods, and class constants.

## New ext-dom features and HTML5 support  [RFC](https://wiki.php.net/rfc/dom_additions_84)  [RFC](https://wiki.php.net/rfc/domdocument_html5_parser)  [Doc](https://www.php.net/manual/en/migration84.new-features.php#migration84.new-features.dom)

PHP < 8.4

```
$dom = new DOMDocument();
$dom->loadHTML(
    <<<'HTML'
        <main>
            <article>PHP 8.4 is a feature-rich release!</article>
            <article class="featured">PHP 8.4 adds new DOM classes that are spec-compliant, keeping the old ones for compatibility.</article>
        </main>
        HTML,
    LIBXML_NOERROR,
);

$xpath = new DOMXPath($dom);
$node = $xpath->query(".//main/article[not(following-sibling::*)]")[0];
$classes = explode(" ", $node->className); // Simplified
var_dump(in_array("featured", $classes)); // bool(true)
```

PHP 8.4

```
$dom = Dom\HTMLDocument::createFromString(
    <<<'HTML'
        <main>
            <article>PHP 8.4 is a feature-rich release!</article>
            <article class="featured">PHP 8.4 adds new DOM classes that are spec-compliant, keeping the old ones for compatibility.</article>
        </main>
        HTML,
    LIBXML_NOERROR,
);

$node = $dom->querySelector('main > article:last-child');
var_dump($node->classList->contains("featured")); // bool(true)
```

New DOM API that includes standards-compliant support for parsing HTML5 documents, fixes several long-standing compliance bugs in the behavior of the DOM functionality, and adds several functions to make working with documents more convenient.

The new DOM API is available within the  `Dom`  namespace. Documents using the new DOM API can be created using the  `Dom\HTMLDocument`  and  `Dom\XMLDocument`  classes.

## Object API for BCMath  [RFC](https://wiki.php.net/rfc/support_object_type_in_bcmath)

PHP < 8.4

```
$num1 = '0.12345';
$num2 = '2';
$result = bcadd($num1, $num2, 5);

echo $result; // '2.12345'
var_dump(bccomp($num1, $num2) > 0); // false
```

PHP 8.4

```
use BcMath\Number;

$num1 = new Number('0.12345');
$num2 = new Number('2');
$result = $num1 + $num2;

echo $result; // '2.12345'
var_dump($num1 > $num2); // false
```

New  `BcMath\Number`  object enables object-oriented usage and standard mathematical operators when working with arbitrary precision numbers.

These objects are immutable and implement the  `Stringable`  interface, so they can be used in string contexts like  `echo $num`.

## New  `array_*()`  functions  [RFC](https://wiki.php.net/rfc/array_find)

PHP < 8.4

```
$animal = null;
foreach (['dog', 'cat', 'cow', 'duck', 'goose'] as $value) {
    if (str_starts_with($value, 'c')) {
        $animal = $value;
        break;
    }
}

var_dump($animal); // string(3) "cat"
```

PHP 8.4

```
$animal = array_find(
    ['dog', 'cat', 'cow', 'duck', 'goose'],
    static fn(string $value): bool => str_starts_with($value, 'c'),
);

var_dump($animal); // string(3) "cat"
```

New functions  [`array_find()`](https://www.php.net/manual/en/function.array-find.php),  [`array_find_key()`](https://www.php.net/manual/en/function.array-find-key.php),  [`array_any()`](https://www.php.net/manual/en/function.array-any.php), and  [`array_all()`](https://www.php.net/manual/en/function.array-all.php)  are available.

## PDO driver specific subclasses  [RFC](https://wiki.php.net/rfc/pdo_driver_specific_subclasses)

PHP < 8.4

```
$connection = new PDO(
    'sqlite:foo.db',
    $username,
    $password,
); // object(PDO)

$connection->sqliteCreateFunction(
    'prepend_php',
    static fn($string) => "PHP {$string}",
);

$connection->query('SELECT prepend_php(version) FROM php');
```

PHP 8.4

```
$connection = PDO::connect(
    'sqlite:foo.db',
    $username,
    $password,
); // object(Pdo\Sqlite)

$connection->createFunction(
    'prepend_php',
    static fn($string) => "PHP {$string}",
); // Does not exist on a mismatching driver.

$connection->query('SELECT prepend_php(version) FROM php');
```

New subclasses  `Pdo\Dblib`,  `Pdo\Firebird`,  `Pdo\MySql`,  `Pdo\Odbc`,  `Pdo\Pgsql`, and  `Pdo\Sqlite`  of  `PDO`  are available.

## `new MyClass()->method()`  without parentheses  [RFC](https://wiki.php.net/rfc/new_without_parentheses)  [Doc](https://www.php.net/manual/en/migration84.new-features.php#migration84.new-features.core.new-chaining)

PHP < 8.4

```
class PhpVersion
{
    public function getVersion(): string
    {
        return 'PHP 8.3';
    }
}

var_dump((new PhpVersion())->getVersion());
```

PHP 8.4

```
class PhpVersion
{
    public function getVersion(): string
    {
        return 'PHP 8.4';
    }
}

var_dump(new PhpVersion()->getVersion());
```

Properties and methods of a newly instantiated object can now be accessed without wrapping the  `new`  expression in parentheses.
